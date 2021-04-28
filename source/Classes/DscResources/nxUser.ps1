
$script:localizedDataNxUser = Get-LocalizedData -DefaultUICulture en-US -FileName 'nxUser.strings.psd1'

[DscResource()]
class nxUser
{
    [DscProperty()]
    [Ensure] $Ensure = [Ensure]::Present

    [DscProperty(Key)]
    [string] $UserName

    [DscProperty()]
    [string] $FullName

    [DscProperty()]
    [string] $Description

    [DscProperty()]
    [string] $Password

    [DscProperty()]
    [System.Nullable[bool]] $Disabled

    [DscProperty()]
    [string] $PasswordChangeRequired

    [DscProperty()]
    [string] $HomeDirectory

    [DscProperty()]
    [string] $GroupID

    [DscProperty(NotConfigurable)]
    [Reason[]] $Reasons

    [nxUser] Get()
    {
        Write-Verbose -Message (
            $script:localizedDataNxUser.RetrieveUser -f $this.UserName
        )

        $nxLocalUser = Get-nxLocalUser -UserName $this.UserName
        $currentState = [nxUser]::new()

        if ($nxLocalUser)
        {
            Write-Verbose -Message ($script:localizedDataNxUser.nxUserFound -f $this.UserName)

            # Cast the object to Boolean.

            $currentState.Ensure        = [Ensure]::Present
            $currentState.UserName      = $nxLocalUser.UserName
            $currentState.FullName      = $nxLocalUser.FullName
            $currentState.Description   = $nxLocalUser.Description
            $currentState.Password      = $nxLocalUser.EtcShadow.EncryptedPassword
            $currentState.Disabled      = $nxLocalUser.isDisabled()
            # $currentState.PasswordChangeRequired --> this is a WriteNoRead
            $currentState.HomeDirectory = $nxLocalUser.HomeDirectory

            # get the current primary group as an ID or a string based on what is Desired
            if ($this.GroupID -as [int])
            {
                $currentState.GroupId = $nxLocalUser.GroupID
            }
            else
            {
                # Expected GroupID is a string, resolve the Current GroupId's name.
                $currentState.GroupId = (Get-nxLocalGroup).Where({ $_.GroupID -eq $nxLocalUser.GroupID }).GroupName | Select-Object -First 1
            }

            $valuesToCheck = @(
                # UserName can be skipped because it's determined with Ensure absent/present
                'Ensure'
                'FullName'
                'Description'
                'Password'
                'Disabled'
                'HomeDirectory'
                'GroupID'
            ).Where({ $null -ne $this.$_ }) #remove properties not set from comparison

            $compareStateParams = @{
                CurrentValues = ($currentState | Convert-ObjectToHashtable)
                DesiredValues = ($this | Convert-ObjectToHashtable)
                ValuesToCheck = $valuesToCheck
            }

            $compareState = Compare-DscParameterState @compareStateParams

            $currentState.reasons = switch ($compareState.Property)
            {
                'Ensure'
                {
                    [Reason]@{
                        Code = '{0}:{1}:Ensure' -f $this.GetType(), $this.UserName
                        Phrase = $script:localizedDataNxUser.nxLocalUserShouldBeAbsent -f $this.UserName
                    }
                }

                'FullName'
                {
                    [Reason]@{
                        Code = '{0}:{1}:FullName' -f $this.GetType(), $this.UserName
                        Phrase = $script:localizedDataNxUser.FullNameMismatch -f $this.FullName, $currentState.FullName
                    }
                }

                'Description'
                {
                    [Reason]@{
                        Code = '{0}:{1}:Description' -f $this.GetType(), $this.UserName
                        Phrase = $script:localizedDataNxUser.DescriptionMismatch -f $this.Description, $currentState.Description
                    }
                }

                'Password'
                {
                    [Reason]@{
                        Code = '{0}:{1}:Password' -f $this.GetType(), $this.UserName
                        Phrase = $script:localizedDataNxUser.PasswordMismatch -f $this.Password, $currentState.Password
                    }
                }

                'Disabled'
                {
                    [Reason]@{
                        Code = '{0}:{1}:Disabled' -f $this.GetType(), $this.UserName
                        Phrase = $script:localizedDataNxUser.DisabledMismatch -f $this.Disabled, $currentState.Disabled
                    }
                }

                'PasswordChangeRequired'
                {
                    [Reason]@{
                        Code = '{0}:{1}:PasswordChangeRequired' -f $this.GetType(), $this.UserName
                        Phrase = $script:localizedDataNxUser.PasswordChangeRequiredMismatch -f $this.PasswordChangeRequired, $currentState.PasswordChangeRequired
                    }
                }

                'HomeDirectory'
                {
                    [Reason]@{
                        Code = '{0}:{1}:HomeDirectory' -f $this.GetType(), $this.UserName
                        Phrase = $script:localizedDataNxUser.HomeDirectoryMismatch -f $this.HomeDirectory, $currentState.HomeDirectory
                    }
                }

                'GroupID'
                {
                    [Reason]@{
                        Code = '{0}:{1}:GroupID' -f $this.GetType(), $this.UserName
                        Phrase = $script:localizedDataNxUser.GroupIDMismatch -f $this.GroupID, $currentState.GroupID
                    }
                }
            }
        }
        else
        {
            $currentState.Ensure = [Ensure]::Absent
            $currentState.UserName = $this.UserName
            Write-Verbose -Message ($script:localizedDataNxUser.nxLocalUserNotFound -f $this.UserName)
            if ($this.Ensure -ne $currentState.Ensure)
            {
                $currentState.reasons = [Reason]@{
                    Code = '{0}:{1}:Ensure' -f $this.GetType(), $this.UserName
                    Phrase = $script:localizedDataNxUser.nxLocalUserNotFound -f $this.UserName
                }
            }
            else
            {
                Write-Verbose -Message ('The user ''{0}'' is in the desired state' -f $this.UserName)
            }
        }

        return $currentState
    }

    [void] Set()
    {
        $currentState = $this.Get()

        if ($this.Ensure -eq [Ensure]::Present) # must be present
        {
            if ($currentState.Ensure -eq [Ensure]::Absent) # but is absent
            {
                Write-Verbose -Message (
                    $script:localizedDataNxUser.CreateUser -f $this.UserName
                )

                $newNxLocalUserParam = @{
                    Username    = $this.UserName
                    Passthru    = $true
                    ErrorAction = 'Stop'
                    Confirm     = $false
                }

                if ($this.GroupID)
                {
                    $newNxLocalUserParam.Add(
                        'PrimaryGroup', $this.GroupID
                    )
                }

                if ($this.Password)
                {
                    $newNxLocalUserParam.Add(
                        'EncryptedPassword', $this.Password
                    )
                }

                if ($this.HomeDirectory)
                {
                    $newNxLocalUserParam.Add(
                        'HomeDirectory', $this.HomeDirectory
                    )
                }

                if ($this.FullName -or $this.Description)
                {
                    $newNxLocalUserParam.Add(
                        'UserInfo',
                        ('{0},,,,{1},' -f $this.FullName, $this.Description)
                    )
                }

                if ($this.PasswordChangeRequired)
                {
                    # Make it expired yesterday
                    $newNxLocalUserParam.Add(
                        'ExpireOn',
                        (Get-Date).AddDays(-1)
                    )
                }

                $localUser = New-nxLocalUser @newNxLocalUserParam
            }
            else
            {
                # The user exists but has some non-compliant settings (found in the reasons)

                # Get user so we can set other properties
                $localUser = Get-nxLocalUser -UserName $this.UserName -ErrorAction Stop

                switch -Regex ($currentState.Reasons.Code)
                {
                    ':FullName$'
                    {

                    }

                    ':Description$'
                    {

                    }

                    ':Password$'
                    {

                    }

                    ':Disabled$'
                    {

                    }

                    ':HomeDirectory$'
                    {

                    }

                    ':GroupID$'
                    {
                        Write-Verbose -Message ('Forcing the PrimaryGroup to be ID {0}' -f  $this.GroupID)
                    }
                }
            }

            # Set other properties if needed
            if ($this.Disabled -and -not $localUser.IsDisabled())
            {
                Write-Verbose -Message "Disabling user account '$($this.UserName)'."
                Disable-nxLocalUser -UserName $localUser.UserName
            }

            Write-Verbose -Message (
                $script:localizedDataNxUser.SettingProperties -f $this.UserName
            )
        }
        else
        {
            # The user must not exist
            if ($currentState.Ensure -eq 'Present')
            {
                # But it does, remove it
                Write-Verbose -Message (
                    $script:localizedDataNxUser.RemoveNxLocalUser -f $this.Path
                )

                Remove-nxLocalUser -UserName $this.Username -Confirm:$false
            }
        }
    }

    [bool] Test()
    {
        $currentState = $this.Get()
        $testTargetResourceResult = $currentState.Reasons.count -eq 0

        return $testTargetResourceResult
    }
}
