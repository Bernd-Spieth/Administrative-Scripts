
<#
    This script changes the owner of the profile folders to the user of the profile folder.
    
    It works this way:

    1. It gets the priviliges to access all files and folders even if the executing user of the script has noc access to the items.
    2. It enables inheritance on the profile folder so that the principals of the root folder are added to the profile folder.
    3. It sets the owner of the profile folder to the user of the profile folder
    4. It disables the inheritance of the profile folder and keeps the inherited permissions
    5. It sets the owner of all sub folders to the user of the profile folder

    This scripts uses the PowerShell module NTFSSecurity 

    Install:
    https://github.com/raandree/NTFSSecurity

    Information:
    https://www.windowspro.de/wolfgang-sommergut/ntfs-rechte-anzeigen-zuweisen-entfernen-powershell-modul-ntfssecurity
    https://kohn.blog/powershell/berechtigungsverwaltung-mittels-powershell-modul-ntfssecurity
    https://blogs.technet.microsoft.com/fieldcoding/2014/12/05/ntfssecurity-tutorial-1-getting-adding-and-removing-permissions/
#>

# Install the required module
Import-Module NTFSSecurity

#region variables

$netBiosDomainName = "mydomain"

#endregion variables

#region functions
function Get-LogDate
{
    Get-Date -Format "[yyyy-MM-dd_HH-mm-ss]"
}

function Is-Admin
{
    $result = $false

    if ((New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
    {
      $result = $true
    }

    $result
}
#endregion functions

if (!(Is-Admin))
{
    Write-Host -ForegroundColor Yellow ("{0} This PowerShell script needs to run in an evelated process. Please start this script as Administrator. Script will stop." -f (Get-LogDate))
    Exit
}

# If you need to process all folder comment this line and the where filter on the second line
$profileFolderName = Read-Host "Please enter the name of the folder under 'F:\Persönlich' whose permissions you want to reset"

$profileFolders = Get-ChildItem -Path "f:\Persönlich" -Directory | Where {$_.Name -like $profileFolderName}

if (!$profileFolders)
{
    Write-Host ("{0} Profile folder '{1}' not found. Exiting..." -f (Get-LogDate), $profileFolderName)
}

$usersNotFound = @()
$profilesProcessed = 0

# Enable some priviliges to bypass ACL
Enable-Privileges

foreach ($profileFolder in $profileFolders)
{
    Write-Host -ForegroundColor Cyan ("{0} Processing folder '{1}'..." -f (Get-LogDate), $profileFolder.FullName)

    $pathName = $profileFolder.PSChildName.ToString().ToLower()

    $userName = $pathName -replace ".v3"
    $userName = $pathName -replace ".v2"
    $userName = $pathName -replace ".star-trek"

    try
    {
        Write-Host ("{0} Trying to find user '{1}' in Active Directory..." -f (Get-LogDate), $userName)

        $result = Get-AdUser -filter {sAMAccountName -Like $userName}

        if ($result)
        {
            Write-Host ("{0} User '{1}' found in Active Directory." -f (Get-LogDate), $userName)

            if(!$result.Enabled)
            {
                Write-Host -ForegroundColor Yellow ("{0} User '{1}' is disabled." -f (Get-LogDate), $userName)
            }

            $fullUserName = "{0}\{1}" -f $netBiosDomainName, $userName

            Write-Host -ForegroundColor White ("{0} Enable NTFS inheritance on profile folder '{1}'..." -f (Get-LogDate), $userName)

            # Enable inheritance on the root directory
            Enable-NTFSAccessInheritance -Path $profileFolder.FullName

            Write-Host -ForegroundColor White ("{0} Enable NTFS inheritance all items of profile folder '{1}'..." -f (Get-LogDate), $userName)

            # Find all items with inheritance disabled
            $items = Get-ChildItem2 $profileFolder.FullName -Recurse -Force

            # Enable inheritance on those items
            $items | Get-NTFSInheritance | Where-Object { -not $_.AccessInheritanceEnabled } | Enable-NTFSAccessInheritance -PassThru 

            Write-Host -ForegroundColor White ("{0} Set owner of profile folder '{1}'..." -f (Get-LogDate), $userName)

            # Set owner on root directory
            Set-NTFSOwner $profileFolder.FullName -Account $fullUserName

            Write-Host -ForegroundColor White ("{0} Reseting permissions of all items of profile folder '{1}' to inherited permissions..." -f (Get-LogDate), $userName)

            # Reset permissions to inherited permissions 
            Get-ChildItem2 $profileFolder.FullName -Filter * -Recurse -Force | Get-NTFSAccess -ExcludeInherited | Remove-NTFSAccess -PassThru

            Write-Host -ForegroundColor White ("{0} Disabling inheritance to profile folder '{1}'..." -f (Get-LogDate), $userName)

            # Disable inheritance on the profile directory
            Disable-NTFSAccessInheritance -Path $profileFolder.FullName

            # Give the owner full acccess. Otherwise she would have owner permissions to "This Folder only" because it is inherited from the root folder. 
            # If an administrator would copy restored files into the MyFiles folder the user would not see it 
            Add-NTFSAccess -Account $fullUserName -Path $profileFolder.FullName -AccessRights FullControl

            Write-Host -ForegroundColor Green ("{0} User '{1}' processed" -f (Get-LogDate), $userName)
        }
        else
        {
            Write-Host ("{0} User '{1}' not found in Active Directory. User will be skipped." -f (Get-LogDate), $userName)
            $usersNotFound += $userName
        }
    }
    catch
    {
        Write-Host ("{0} User '{1}' not found in Active Directory. User will be skipped." -f (Get-LogDate), $userName)
        $usersNotFound += $userName
        Exit
    }

    $profilesProcessed++
    Write-Host ("{0} Number of users processed: {1}" -f (Get-LogDate), $profilesProcessed)
}

# Enable priviliges to bypass ACL
Disable-Privileges

$usersNotFound