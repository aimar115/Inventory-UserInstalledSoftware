$ProfileList=Get-WmiObject -Class win32_UserProfile|Where-Object {$_.Special -eq $False}
$Sids = $ProfileList.SID
$InstalledSoftware = New-Object System.Collections.ArrayList
$PCName = (Get-WmiObject Win32_ComputerSystem).Name 
 
#Create WMI Class
$ClassName = "CM_Add_Remove_Programs_User"
function New-WmiClass()
{
    $newClass = New-Object System.Management.ManagementClass("root\cimv2", [String]::Empty, $null) ;
    $newClass["__CLASS"] = $ClassName ;
    $newClass.Qualifiers.Add("Static", $true)
     
    $newClass.Properties.Add("DeviceName", [System.Management.CimType]::String, $false)
    $newClass.Properties["DeviceName"].Qualifiers.Add("key", $true)
    $newClass.Properties["DeviceName"].Qualifiers.Add("read", $true)
     
    $newClass.Properties.Add("UserID", [System.Management.CimType]::String, $false)
    $newClass.Properties["UserID"].Qualifiers.Add("key", $true)
    $newClass.Properties["UserID"].Qualifiers.Add("read", $true)
     
    $newClass.Properties.Add("DisplayName", [System.Management.CimType]::String, $false)
    $newClass.Properties["DisplayName"].Qualifiers.Add("key", $true)
    $newClass.Properties["DisplayName"].Qualifiers.Add("read", $true)
     
    $newClass.Properties.Add("DisplayVersion", [System.Management.CimType]::String, $false)
    $newClass.Properties["DisplayVersion"].Qualifiers.Add("read", $true)
     
    $newClass.Properties.Add("Publisher", [System.Management.CimType]::String, $false)
    $newClass.Properties["Publisher"].Qualifiers.Add("read", $true)
     
    $newClass.Properties.Add("InstallDate", [System.Management.CimType]::String, $false)
    $newClass.Properties["InstallDate"].Qualifiers.Add("read", $true)

    $newClass.Properties.Add("UninstallString", [System.Management.CimType]::String, $false)
    $newClass.Properties["UninstallString"].Qualifiers.Add("read", $true)
    
    $newClass.Properties.Add("InstallLocation", [System.Management.CimType]::String, $false)
    $newClass.Properties["InstallLocation"].Qualifiers.Add("read", $true)
    $newClass.Put()
}
 
# Check whether we already created our custom WMI class on this PC, if not, create it
[void](Get-WmiObject $ClassName -ErrorAction SilentlyContinue -ErrorVariable wmiclasserror)
if ($wmiclasserror)
{
    try {
 
        New-WmiClass
        write-host "Class Created"
    }
    catch
    {
        write-host "Could not create WMI class"
        write-host $wmiclasserror
        Exit 1
    }
}
#remove all instances so only current application titles are listed.  Any files that were removed will be no longer
#be listed in the class or HWInv
Get-WmiObject -Class $ClassName | Remove-WmiObject
 
#User Installs
foreach($sid in $Sids)
{
    $ValidPath = $False
    $ValidPath = test-path "registry::HKEY_USERS\$sid\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
    If($ValidPath -eq $True)
    {
         
        #Find User Name
        $UserPath = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$Sid" -Name ProfileImagePath
        $UserID = ($UserPath.Split("\"))[2]
         
        $Programs = Get-ItemProperty registry::HKEY_USERS\$sid\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\* |  Select-Object DisplayName, DisplayVersion, Publisher, InstallDate, UninstallString, InstallLocation
 
        ForEach($Program in $Programs)
        {
            $Arguments=@{DeviceName=$PCName; `
             UserID = $UserID; `
             displayName=$Program.DisplayName;`
             displayVersion=$Program.DisplayVersion;`
             Publisher=$Program.Publisher; `
             InstallDate=$Program.InstallDate; `
             UninstallString=$Program.UninstallString; `
             InstallLocation=$Program.InstallLocation}
            #$Path = "\\.\ROOT\cimv2:$ClassName"
            Set-WmiInstance -Namespace root\cimv2 -Class $ClassName -Arguments $Arguments | Out-Null
        }
    }
}

#Get-WmiObject -Class CM_Add_Remove_Programs_User
