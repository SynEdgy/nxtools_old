configuration LinuxGroupsMustExclude {
    Import-DscResource -ModuleName nxtools -ModuleVersion 0.3.0

    node LinuxGroupsMustExclude {
        nxGroup LinuxGroupsMustExclude {
            Ensure =  'Present'
            GroupName =  'foobar'
            PreferredGroupID = 1005
            MembersToExclude = 'root','gcolas'
        }
    }
}
