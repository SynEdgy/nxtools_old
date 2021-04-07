function Get-nxLocalGroup
{
    [CmdletBinding(DefaultParameterSetName = 'byGroupName')]
    [OutputType()]
    param
    (
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'byGroupName')]
        [System.String[]]
        [Alias('Group')]
        $GroupName,

        [Parameter(ValueFromPipelineByPropertyName = $true, ParameterSetName = 'byRegexPattern')]
        [regex]
        $Pattern
    )

    begin
    {
        $readEtcGroupCmd = {
            Get-Content -Path '/etc/group' | ForEach-Object -Process {
                [nxLocalGroup]$_
            }
        }
    }

    process
    {
        if ($PSCmdlet.ParameterSetName -ne 'byRegexPattern' -and $PSCmdlet.ParameterSetName -eq 'byGroupName' -and -not $PSBoundParameters.ContainsKey('GroupName'))
        {
            &$readEtcGroupCmd
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'byRegexPattern')
        {
            &$readEtcGroupCmd | Where-Object -FilterScript {
                $_.Groupname -match $Pattern
            }
        }
        else
        {
            $allGroups = &$readEtcGroupCmd
            foreach ($GroupNameEntry in $GroupName)
            {
                $allGroups | Where-Object -FilterScript {
                    $_.Groupname -eq $GroupNameEntry
                }
            }
        }
    }
}
