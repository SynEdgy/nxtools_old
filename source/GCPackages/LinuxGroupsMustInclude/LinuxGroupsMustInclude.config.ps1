configuration LinuxGroupsMustInclude {
    Import-DscResource -ModuleName nxtools -ModuleVersion 0.3.0

    node LinuxGroupsMustInclude {
        GC_LinuxGroup LinuxGroupsMustInclude {
            Ensure =  'Present'
            GroupName =  'foobar'
            PreferredGroupID = 1005
            MembersToIncludeAsString = 'root;gcolas'
        }
    }
}
