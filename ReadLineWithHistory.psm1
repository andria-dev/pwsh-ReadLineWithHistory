Add-Type 'using System.Collections.Generic;';

class Cursor {
  [Int32] $Left;
  [Int32] $Top;
  [Int32] $Index;
  Cursor($Left, $Top) {
    $this.Index = ($Top * [Console]::WindowWidth) + $Left;
    $this.Left = $Left;
    $this.Top = $Top;
  }
  static [Cursor] CursorByIndex($Index, $Offset) {
    $t = [Math]::Floor(($Offset + $Index) / [Console]::WindowWidth);
    $l = $Offset + ($Index - ($t * [Console]::WindowWidth));
    return [Cursor]::new($l, $t);
  }
}

function Get-Cursor {
  return [Cursor]::new([Console]::CursorLeft, [Console]::CursorTop);
}
function Get-CursorRelative([Cursor]$CursorStart) {
  return [Cursor]::CursorByIndex([Console]::CursorLeft - $CursorStart.Left, [Console]::CursorTop - $CursorStart.Top);
}

class History {
  [Collections.Generic.LinkedList[String]] hidden $Storage = [Collections.Generic.LinkedList[String]]::new();
  [Collections.Generic.LinkedListNode[String]] hidden $Current = $null;
  [String] hidden $NextInput = "";

  [psobject] Previous() {
    If ($null -eq $this.Current) {
      If ($null -eq $this.Storage.Last) { return $null; }
      $this.Current = $this.Storage.Last;
      return $this.Current.Value;
    }

    If ($null -eq $this.Current.Previous) { return $null }
    $this.Current = $this.Current.Previous;
    return $this.Current.Value;
  }
  [psobject] Next() {
    If ($null -eq $this.Current) { return $null; }
    If ($null -eq $this.Current.Next) {
      $this.Current = $null;
      return $this.NextInput;
    }
    $this.Current = $this.Current.Next;
    return $this.Current.Value;
  }
  [Void] Append([String] $Value) {
    $this.Storage.AddLast($Value);
    $this.Current = $null;
  }
  [Void] SyncNextInput([String] $Value) {
    $this.NextInput = $Value;
    $this.Current = $null;
  }
}

function Update-ConsoleCursor($Cursor) {
  [Console]::CursorLeft = $Cursor.Left;
  [Console]::CursorTop = $Cursor.Top;
}
function Update-ConsoleCursorByIndex($Cursor, $Index) {
  $CursorRelative = [Cursor]::CursorByIndex($Index, $Cursor.Left);
  [Console]::CursorLeft = $CursorRelative.Left;
  [Console]::CursorTop = $Cursor.Top + $CursorRelative.Top;
}

function Clear-Console($From, $Length) {
  Update-ConsoleCursor $From;
  [Console]::Write(" " * $Length);
  Update-ConsoleCursor $From;
}

function Split-ByIndex($String, $Index) {
  return ($String.Substring(0, $Index), $String.Substring($Index));
}

class ReadLineWithHistory {
  [History]$History = [History]::new();
  ReadLineWithHistory() {}

  [String] ReadLine($Prompt) {

    If ($Prompt) {
      [Console]::Write($Prompt)
    }
    
    $CurrentInput = "";
    $this.History.SyncNextInput("");
    $CursorStart = Get-Cursor;
    
    $ExitLoop = $False
    while (-not $ExitLoop) {
      $CursorRelative = Get-CursorRelative $CursorStart;
      $Key = [Console]::ReadKey();
      Switch ($Key.Key) {
        UpArrow {
          If ($null -ne ($Previous = $this.History.Previous())) {
            # TODO: Clear the input from the console, replace the current input with the previous history item, and write the new current input to the screen.
            Clear-Console $CursorStart $CurrentInput.Length;
            $CurrentInput = $Previous;
            [Console]::Write($CurrentInput); 
            $CursorRelative = Get-CursorRelative $CursorStart;
          }
          Break;
        }
        DownArrow {
          If ($null -ne ($Next = $this.History.Next())) {
            # TODO: Clear the input from the console, replace the current input with the next history item, and write the new current input to the screen.
            Clear-Console $CursorStart $CurrentInput.Length;
            $CurrentInput = $Next;
            [Console]::Write($CurrentInput);
            $CursorRelative = Get-CursorRelative $CursorStart;
          }
          Break;
        }
        LeftArrow {
          # TODO: Move the cursor left by one. If the cursor is at the beginning of a line but there's still more input, move the cursor to the end of the previous line.
          If ($CursorRelative.Index -gt 0) {
            Update-ConsoleCursorByIndex $CursorStart ($CursorRelative.Index - 1);
            $CursorRelative = Get-CursorRelative $CursorStart;
          }
          Break;
        }
        RightArrow {
          # TODO: Move the cursor right by one. If the cursor is at the end of a line but there's still more input, move the cursor to the beginning of the next line.
          If ($CursorRelative.Index -lt $CurrentInput.Length) {
            Update-ConsoleCursorByIndex $CursorStart ($CursorRelative.Index + 1);
            $CursorRelative = Get-CursorRelative $CursorStart;
          }
          Break;
        }
        Home {
          # TODO: Move the cursor back to the cursor start.
          Update-ConsoleCursor $CursorStart;
          $CursorRelative = Get-CursorRelative $CursorStart;
          Break;
        }
        End {
          # TODO: Move the cursor to the end of the input.
          Update-ConsoleCursorByIndex $CursorStart $CurrentInput.Length;
          $CursorRelative = Get-CursorRelative;
          Break;
        }
        Enter {
          $ExitLoop = $True;
          If ($CurrentInput.Length -gt 0) { $this.History.Append($CurrentInput); }
          [Console]::Write("`n");

          Break;
        }
        Backspace {
          # TODO: Move the cursor back by one if not at the beginning, and then erase the console from the current cursor position to the end of the input. After that rewrite the input without the deleted character. Sync with history.
          If ($CursorRelative.Index -lt 1) { Break; }
          ($BeforeCursor, $AfterCursor) = Split-ByIndex $CurrentInput $CursorRelative.Index;
          $BeforeCursor = $BeforeCursor.Substring(0, $BeforeCursor.Length - 1);
          $CurrentInput = $BeforeCursor + $AfterCursor;
          $this.History.SyncNextInput($CurrentInput);
          Update-ConsoleCursorByIndex $CursorStart ($CursorRelative.Index - 1);
          $CursorRelative = Get-CursorRelative $CursorStart;
          [Console]::Write($AfterCursor + ' ');
          Update-ConsoleCursorByIndex $CursorStart $CursorRelative.Index;

          Break;
        }
        Delete {
          # TODO: Erase and rewrite just as when a Backspace is received, but don't move the cursor. Instead simply delete the character in front of the cursor. Sync with history.
          If ($CursorRelative.Index -ge $CurrentInput.Length) { Break; }
          ($BeforeCursor, $AfterCursor) = Split-ByIndex $CurrentInput $CursorRelative.Index;
          $AfterCursor = $AfterCursor.Substring(1, $AfterCursor.Length - 1);
          $CurrentInput = $BeforeCursor + $AfterCursor;
          $this.History.SyncNextInput($CurrentInput);
          [Console]::Write($AfterCursor + ' ');
          Update-ConsoleCursorByIndex $CursorStart $CursorRelative.Index;
          Break;
        }
        Default {
          If ($Key.KeyChar) {
            # TODO: Add the character to the input at the current cursor position/index, rewrite everything that goes after the cursor, and sync with history.
            ($BeforeCursor, $AfterCursor) = Split-ByIndex $CurrentInput $CursorRelative.Index;
            $CurrentInput = $BeforeCursor + $Key.KeyChar + $AfterCursor;
            $this.History.SyncNextInput($CurrentInput);
            $CursorRelative = Get-CursorRelative $CursorStart;
            If ($AfterCursor) {
              [Console]::Write($AfterCursor -Join '');
              Update-ConsoleCursorByIndex $CursorStart $CursorRelative.Index;
            }
          }
          Break;
        }
      }
    }

    return $CurrentInput;
  }
}

function New-ReadLineWithHistory {
  return [ReadLineWithHistory]::new();
}
Export-ModuleMember -Function New-ReadLineWithHistory;