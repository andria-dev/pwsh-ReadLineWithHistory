# pwsh-ReadLineWithHistory

Works on Linux.

## Usage

```pwsh
Import-Module ReadLineWithHistory;
$Reader = New-ReadLineWithHistory;

while ($True) {
  $Command = $Reader.ReadLine("$env:USER - $env:PWD> ");
  # Process the command
}

# Or

$Input = $Reader.ReadLine("PROMPT: ");
# Process the input
$Input = $Reader.ReadLine("PROMPT: ");
# Process the input
```
