
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
    [System.Nullable[int]] $GroupID

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
            $currentState.PasswordChangeRequired = $nxLocalUser
            $currentState.HomeDirectory = $nxLocalUser.HomeDirectory
            $currentState.GroupID       = $nxLocalUser.GroupID

            $valuesToCheck = @(
                # UserName can be skipped because determines Ensure absent/present
                'Ensure'
                'FullName'
                'Description'
                'Password'
                'Disabled'
                'PasswordChangeRequired'
                'HomeDirectory'
                'GroupID'
            ).Where({$null -ne $this.$_}) #remove properties not set from comparison

            $compareStateParams = @{
                CurrentValues = ($currentState | Convert-ObjectToHashtable)
                DesiredValues = ($this | Convert-ObjectToHashtable)
                ValuesToCheck = $valuesToCheck
            }

            $compareState = Compare-DscParameterState @compareStateParams | Where-Object {$_.InDesiredState -eq $false }

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
            Write-Verbose -Message ($script:localizedDataNxUser.nxLocalUserNotFound -f $this.UserName)
            if ($this.Ensure -ne $currentState.Ensure)
            {
                $currentState.reasons = [Reason]@{
                    Code = '{0}:{1}:Ensure' -f $this.GetType(), $this.UserName
                    Phrase = $script:localizedDataNxUser.nxLocalUserNotFound -f $this.UserName
                }
            }
        }

        return $currentState
    }

    [void] Set()
    {
        $currentState = $this.Get()

        if ($this.Ensure -eq [Ensure]::Present)
        {
            if ($currentState.Ensure -eq [Ensure]::Absent)
            {
                Write-Verbose -Message (
                    $script:localizedDataNxUser.CreateUser -f $this.UserName
                )

                # New User
            }
            else
            {
                # Get user so we can set other properties
            }

            Write-Verbose -Message (
                $script:localizedDataNxUser.SettingProperties -f $this.UserName
            )

            # Set other properties if needed
        }
        else
        {
            # The user must not exist
            if ($currentState.Ensure -eq 'Present')
            {
                # But it does, remove it
                Write-Verbose -Message (
                    $script:localizedDataNxUser.RemoveFolder -f $this.Path
                )

                Remove-nxLocalUser -UserName $this.Username
            }
        }
    }

    [bool] Test()
    {
        $testTargetResourceResult = $false
        $currentState = $this.Get()

        if ($this.Ensure -eq [Ensure]::Present)
        {
            # if $this should exist, make sure there's no reason of non-compliance
            Write-Verbose -Message $script:localizedDataNxUser.EvaluateProperties

            $testTargetResourceResult = $currentState.Reasons.count -eq 0
        }
        else
        {
            if ($this.Ensure -eq $currentState.Ensure)
            {
                $testTargetResourceResult = $true
            }
        }

        return $testTargetResourceResult
    }
}
