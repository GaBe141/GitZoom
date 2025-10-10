# Helper functions for mutation testing

function Find-Mutations {
    param(
        [string]$ScriptContent
    )
    $mutations = @()
    $lines = $ScriptContent.Split([Environment]::NewLine)

    for ($i = 0; $i -lt $lines.Length; $i++) {
        $line = $lines[$i]
        $lineNumber = $i + 1
        $offset = $ScriptContent.IndexOf($line)

        # Mutation 1: Relational Operator Replacement
        $relationalOperators = @{
            '-eq' = '-ne'
            '-ne' = '-eq'
            '-gt' = '-le'
            '-ge' = '-lt'
            '-lt' = '-ge'
            '-le' = '-gt'
        }
        foreach ($op in $relationalOperators.Keys) {
            if ($line -match $op) {
                $mutations += @{
                    Line = $lineNumber
                    Type = 'RelationalOperator'
                    OriginalValue = $op
                    NewValue = $relationalOperators[$op]
                    Start = $offset + ($line.IndexOf($op))
                    Length = $op.Length
                }
            }
        }

        # Mutation 2: Logical Operator Replacement
        $logicalOperators = @{
            '-and' = '-or'
            '-or' = '-and'
        }
        foreach ($op in $logicalOperators.Keys) {
            if ($line -match $op) {
                $mutations += @{
                    Line = $lineNumber
                    Type = 'LogicalOperator'
                    OriginalValue = $op
                    NewValue = $logicalOperators[$op]
                    Start = $offset + ($line.IndexOf($op))
                    Length = $op.Length
                }
            }
        }

        # Mutation 3: String Literal Modification (simple version)
        if ($line -match '"([^"]+)"') {
            $originalString = $matches[1]
            if ($originalString) {
                $mutatedString = "MUTATED_$originalString"
                 $mutations += @{
                    Line = $lineNumber
                    Type = 'StringLiteral'
                    OriginalValue = "`"$originalString`""
                    NewValue = "`"$mutatedString`""
                    Start = $offset + ($line.IndexOf("`"$originalString`""))
                    Length = "`"$originalString`"".Length
                }
            }
        }

        # Mutation 4: Remove '!' or '-not'
        if ($line -match '(-not|\!)') {
             $mutations += @{
                Line = $lineNumber
                Type = 'NegationRemoval'
                OriginalValue = $matches[0]
                NewValue = ''
                Start = $offset + ($line.IndexOf($matches[0]))
                Length = $matches[0].Length
            }
        }
    }
    return $mutations
}
