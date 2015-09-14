<#
    .SYNOPSIS
        Detect installed and not installed features to output a DSC file
    .DESCRIPTION
        This script will return a list of features that are installed and not installed
        for the server you run it on. This can be viewed as a basic starting point in
        getting DSC up and running for a given server. Once you have this information
        you can use it to simply make sure this server always has these settings, or
        add to it with more DSC Resources.
    .EXAMPLE
        .\New-DscFile.ps1 -Name adfs01 |Out-File .\dsc-config.ps1

        This will output a DSC with only installed features
    .EXAMPLE
        .\New-DscFile.ps1 -Name adfs01 -All |Out-File .\dsc-config.ps1

        This will output a DSC with both installed and not installed features
    .NOTES
        You will most likely need to be a local/domain admin for this to work.
#>
Param
(
[string]$Name = 'Defaults',
[switch]$AllFeatures,
[switch]$AllServices
)
Begin
{
    if (!(Get-Module ServerManager))
    {
        Import-Module ServerManager
        }
    $InstalledFeatures = Get-WindowsFeature |Where-Object {$_.Installed -eq $true}
    if ($AllFeatures)
    {
        $NotInstalledFeatures = Get-WindowsFeature |Where-Object {$_.Installed -eq $false}
        }
    $RunningServices = Get-WmiObject -Query "SELECT * FROM Win32_Service WHERE State='Running'"
    if ($AllServices)
    {
        $NotRunningServices = Get-WmiObject -Query "SELECT * FROM Win32_Service WHERE State!='Running'"
        }
    $GPOs = Get-WmiObject -Namespace root\rsop\computer -Query "SELECT * FROM RSOP_GPO" |Select-Object -Property Name, GUIDName, ID, AccessDenied, FileSystemPath, FilterAllowed, FilterId, Version
    }
Process
{
    Write-Output     "Configuration $($Name)"
    Write-Output     "{"
    Write-Output     "    param"
    Write-Output     "    ("
    Write-Output     "    [Parameter(Mandatory=`$true)]"
    Write-Output     "    [ValidateNotNullOrEmpty()]"
    Write-Output     "    [string]`$ComputerName"
    Write-Output     "    )"
    Write-Output     "    Node `$ComputerName"
    Write-Output     "    {"
    #
    #region Collect Features
    #
    Write-Output     "        #"
    Write-Output     "        #region Installed Windows Features"
    Write-Output     "        #"
    foreach ($Feature in $InstalledFeatures)
    {
        Write-Output     "        WindowsFeature $($Feature.Name.Replace('-',''))"
        Write-Output     "        {"
        Write-Output     "            Name = `"$($Feature.Name)`""
        Write-Output     "            Ensure = `"Present`""
        Write-Output     "            }"
        }
    Write-Output     "        #"
    Write-Output     "        #endregion"
    Write-Output     "        #"
    if ($AllFeatures)
    {
        Write-Output     "        #"
        Write-Output     "        #region Not Installed Windows Features"
        Write-Output     "        #"
        foreach ($Feature in $NotInstalledFeatures)
        {
            Write-Output     "        WindowsFeature $($Feature.Name.Replace('-',''))"
            Write-Output     "        {"
            Write-Output     "            Name = `"$($Feature.Name)`""
            Write-Output     "            Ensure = `"Absent`""
            Write-Output     "            }"
            }
        Write-Output     "        #"
        Write-Output     "        #endregion"
        Write-Output     "        #"
        }
    #
    #endregion
    #
    #
    #region Collect Services
    #
    Write-Output     "        #"
    Write-Output     "        #region Running Services"
    Write-Output     "        #"
    foreach ($Service in $RunningServices)
    {
        Write-Output     "        Service $($Service.Name.Replace(' ',''))"
        Write-Output     "        {"
        Write-Output     "            Name = `"$($Service.Name)`""
        switch ($Service.StartName.ToLower())
        {
            'localsystem'
            {
                Write-Output     "            BuiltInAccount = `"LocalSystem`""
                }
            'nt authority\localservice'
            {
                Write-Output     "            BuiltInAccount = `"LocalService`""
                }
            'nt authority\networkservice'
            {
                Write-Output     "            BuiltInAccount = `"NetworkService`""
                }
            default
            {
                Write-Output     "            # BuiltInAccount = `"$($Service.StartName)`""
                }
            }
        switch ($Service.StartMode.ToLower())
        {
            'auto'
            {
                Write-Output     "            StartupType = `"Automatic`""
                }
            'manual'
            {
                Write-Output     "            StartupType = `"Manual`""
                }
            'disabled'
            {
                Write-Output     "            StartupType = `"Disabled`""
                }
            }
        Write-Output     "            State = `"$($Service.State)`""
        Write-Output     "            }"
        }
    Write-Output     "        #"
    Write-Output     "        #endregion"
    Write-Output     "        #"
    if ($AllServices)
    {
        Write-Output     "        #"
        Write-Output     "        #region Stopped Services"
        Write-Output     "        #"
        foreach ($Service in $NotRunningServices)
        {
            Write-Output     "        Service $($Service.Name.Replace(' ',''))"
            Write-Output     "        {"
            Write-Output     "            Name = `"$($Service.Name)`""
            switch ($Service.StartName.ToLower())
            {
                'localsystem'
                {
                    Write-Output     "            BuiltInAccount = `"LocalSystem`""
                    }
                'nt authority\localservice'
                {
                    Write-Output     "            BuiltInAccount = `"LocalService`""
                    }
                'nt authority\networkservice'
                {
                    Write-Output     "            BuiltInAccount = `"NetworkService`""
                    }
                default
                {
                    Write-Output     "            # BuiltInAccount = `"$($Service.StartName)`""
                    }
                }
            switch ($Service.StartMode.ToLower())
            {
                'auto'
                {
                    Write-Output     "            StartupType = `"Automatic`""
                    }
                'manual'
                {
                    Write-Output     "            StartupType = `"Manual`""
                    }
                'disabled'
                {
                    Write-Output     "            StartupType = `"Disabled`""
                    }
                }
            Write-Output     "            State = `"$($Service.State)`""
            Write-Output     "            }"
            }
        Write-Output     "        #"
        Write-Output     "        #endregion"
        Write-Output     "        #"
        }
    #
    #endregion
    #
    #
    #region Collect Users
    #
    Add-Type -AssemblyName System.DirectoryServices.AccountManagement;
    $ContextType = New-Object -TypeName System.DirectoryServices.AccountManagement.PrincipalContext('Machine');
    $UserPrincipal = New-Object System.DirectoryServices.AccountManagement.UserPrincipal($ContextType);
	$Searcher = New-Object -TypeName System.DirectoryServices.AccountManagement.PrincipalSearcher;
	$Searcher.QueryFilter = $UserPrincipal;
    $Users = $Searcher.FindAll();
    Write-Output     "        #"
    Write-Output     "        #region Local Users"
    Write-Output     "        #"
    foreach ($User in $Users)
    {
        Write-Output     "        User $($User.Name.Replace(' ',''))"
        Write-Output     "        {"
        Write-Output     "            UserName = `"$($User.Name)`""
        Write-Output     "            Description = `"$($User.Description)`""
        Write-Output     "            Disabled = $(!($User.Enabled))"
        Write-Output     "            Ensure = `"Present`""
        Write-Output     "            }"
        }
    Write-Output     "        #"
    Write-Output     "        #endregion"
    Write-Output     "        #"
    #
    #endregion
    #
    #
    #region Collect Groups
    #
    $GroupPrincipal = New-Object System.DirectoryServices.AccountManagement.GroupPrincipal($ContextType);
    $Searcher = New-Object -TypeName System.DirectoryServices.AccountManagement.PrincipalSearcher;
    $Searcher.QueryFilter = $GroupPrincipal;
    $Groups = $Searcher.FindAll();
    Write-Output     "        #"
    Write-Output     "        #region Local Groups"
    Write-Output     "        #"
    foreach ($Group in $Groups)
    {
        Write-Output     "        Group $($Group.Name.Replace(' ','').Replace('-',''))"
        Write-Output     "        {"
        Write-Output     "            GroupName = `"$($Group.Name)`""
        Write-Output     "            Description = `"$($Group.Description)`""
        Write-Output     "            Ensure = `"Present`""
        Write-Output     "            }"
        }
    Write-Output     "        #"
    Write-Output     "        #endregion"
    Write-Output     "        #"
    #
    #endregion
    #
    #
    #region Collect Netstat
    #
    $netstat = netstat -a -n -o -p TCP
    [regex]$regexTCP = '(?<Protocol>\S+)\s+((?<LAddress>(2[0-4]\d|25[0-5]|[01]?\d\d?)\.(2[0-4]\d|25[0-5]|[01]?\d\d?)\.(2[0-4]\d|25[0-5]|[01]?\d\d?)\.(2[0-4]\d|25[0-5]|[01]?\d\d?))|(?<LAddress>\[?[0-9a-fA-f]{0,4}(\:([0-9a-fA-f]{0,4})){1,7}\%?\d?\]))\:(?<Lport>\d+)\s+((?<Raddress>(2[0-4]\d|25[0-5]|[01]?\d\d?)\.(2[0-4]\d|25[0-5]|[01]?\d\d?)\.(2[0-4]\d|25[0-5]|[01]?\d\d?)\.(2[0-4]\d|25[0-5]|[01]?\d\d?))|(?<RAddress>\[?[0-9a-fA-f]{0,4}(\:([0-9a-fA-f]{0,4})){1,7}\%?\d?\]))\:(?<RPort>\d+)\s+(?<State>\w+)\s+(?<PID>\d+$)'
    $Listening = @()
    foreach ($Line in $Netstat)
    {
        switch -regex ($Line.Trim())
        {
            $RegexTCP
            {
                $MyProtocol = $Matches.Protocol
                $MyLocalAddress = $Matches.LAddress
                $MyLocalPort = $Matches.LPort
                $MyRemoteAddress = $Matches.Raddress
                $MyRemotePort = $Matches.RPort
                $MyState = $Matches.State
                $MyPID = $Matches.PID
                $MyProcessName = (Get-Process -Id $Matches.PID -ErrorAction SilentlyContinue).ProcessName
                $MyProcessPath = (Get-Process -Id $Matches.PID -ErrorAction SilentlyContinue).Path
                $MyUser = ""
                try
                {
                    $MyUser = (Get-WmiObject -Class Win32_Process -Filter ("ProcessId = "+$Matches.PID)).GetOwner().User
                    }
                catch
                {}
                }
            }
        $LineItem = New-Object -TypeName PSobject -Property @{
            Protocol = $MyProtocol
            LocalAddress = $MyLocalAddress
            LocalPort = $MyLocalPort
            RemoteAddress = $MyRemoteAddress
            RemotePort = $MyRemotePort
            State = $MyState
            PID = $MyPID
            ProcessName = $MyProcessName
            ProcessPath = $MyProcessPath
            User = $MyUser
            }
        if ($LineItem.LocalAddress = "0.0.0.0")
        {
            if (($LineItem.State) -and ($LineItem.State.ToUpper() -eq "LISTENING"))
            {
                if ($LineItem.User)
                {
                    $User = $LineItem.User.ToLower()
                    }
                else
                {
                    $User = "system"
                    }
                $Listening += $LineItem
                }
            }
        }
    #
    # $Listening contains a list of services/applications listening on a given port + protocol
    #
    $Rules = @()
    foreach ($Listener in $Listening)
    {
        $Protocol = $Listener.Protocol.ToUpper()
        $Port = $Listener.LocalPort
        $Rules += New-Object -TypeName psobject -Property @{
            DisplayName = "Allow $($Protocol) traffic over port $($Port)"
            Name = "AUTOGEN_$($Protocol)_$($Port)"
            Action = 'Allow'
            Description = $Listener
            Direction = 'Inbound'
            Enabled = 'True'
            LocalPort = $Listener.LocalPort
            Protocol = $Listener.Protocol
            }
        }
    #
    #endregion
    #
    Write-Output     "        }" # End node block
    Write-Output     "    }"     # End configuration block
    }
End
{
    $InstalledFeatures |Export-Csv .\InstalledFeatures.csv -NoTypeInformation -Force
    $NotInstalledFeatures |Export-Csv .\NotInstalledFeatures.csv -NoTypeInformation -Force
    $RunningServices |Export-Csv .\RunningServices.csv -NoTypeInformation -Force
    $NotRunningServices |Export-Csv .\NotRunningServices.csv -NoTypeInformation -Force
    $Users |Export-Csv .\Users.csv -NoTypeInformation -Force
    $Groups |Export-Csv .\groups.csv -NoTypeInformation -Force
    foreach ($Group in $Groups){$Group.Members |Export-Csv ".\$($Group.Name.Replace(' ','').Replace('-',''))-members.csv" -NoTypeInformation -Force}
    $GPOs |Export-Csv .\GPOs.csv -NoTypeInformation -Force
    $Rules |Export-Csv .\Listeningports.csv -NoTypeInformation -Force
    }
