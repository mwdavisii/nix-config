#Requires -Version 7.2


$NixPackageVersion = "nixos-23.11"
$NixURL = "https://channels.nixos.org/${NixPackageVersion}latest-nixos-"

$dirPath = "~\vms"
$sshPath = "~\.ssh"


#PS Check for Admin Rights
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) {
    write-host "This script needs admin rights to continue. Please run as administrator."
    { Exit }
}

function Execute-Command {
    param(
        [Parameter(Mandatory=$true)]
        [string]$command
    )

    $process = Start-Process -FilePath $command -Wait
    if ($process.ExitCode -ne 0) {
        Write-Error "Command '$command' failed with exit code $process.ExitCode."
    }
}

function Install-ChocoPackage {
# Code from https://rafaelmedeiros94.medium.com/installing-tools-using-powershell-and-chocolatey-windows-60d02ff7a7b9
    [cmdletbinding()]
    param(
        [String]$PackageName
    )

    $ChocoLibPath = "C:\ProgramData\chocolatey\lib"

    if(-not(test-path $ChocoLibPath)){
        Set-ExecutionPolicy Bypass -Scope Process -Force; 
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072;
        iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        Restart-Computer
    }
    
    #Test if the package folder exists on Choco Lib folder
    if (!((test-path "$ChocoLibPath\$PackageName"))) {

        Write-Host "[INFO]Installing $PackageName..." -ForegroundColor Yellow
        $start_time = Get-Date
        #Install the package without confirmation prompt
        choco install -y -v $PackageName 
        Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"

    }
    else {

        Write-host  "[INFO]$PackageName is already installed." -ForegroundColor Green
    }
}

function Build-VirtualBox {
    param(
        [Parameter(Mandatory=$true)]
        [string]$VMName
    )
    param(
        [Parameter(Mandatory=$true)]
        [string]$VMPath
    )
    #create disk
    VBoxManage createvm --name $name --ostype "Linux_64" --register --basefolder `$dirPath`
    #create memory and network
    Execute-Command -command "VBoxManage modifyvm ${VMName} --ioapic on"
    Execute-Command -command "VBoxManage modifyvm ${VMName} --memory 2048 --vram 128"
    Execute-Command -command "VBoxManage modifyvm ${VMName} --nic1 nat"
    Execute-Command -command "VBoxManage createhd --filename "${VMPath}"/${VMName}/${VMName}_DISK.vdi --size 40000 --format VDI"
    Execute-Command -command "VBoxManage storagectl ${VMName} --name "SATA Controller" --add sata --controller IntelAhci"
    Execute-Command -command "VBoxManage storageattach ${VMName} --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium  "${VMPath}"/${VMName}/${VMName}_DISK.vdi"
    Execute-Command -command "VBoxManage storagectl ${VMName} --name "IDE Controller" --add ide --controller PIIX4"
    Execute-Command -command "VBoxManage storageattach ${VMName} --storagectl "IDE Controller" --port 1 --device 0 --type dvddrive --medium "${VMPath}"/nixos.iso"       
    Execute-Command -command "VBoxManage modifyvm ${VMName} --boot1 dvd --boot2 disk --boot3 none --boot4 none"
    Execute-Command -command "VBoxManage modifyvm ${VMName} --vrde on"
    Execute-Command -command "VBoxManage modifyvm ${VMName} --vrdemulticon on --vrdeport 10001"
    Execute-Command -command "VBoxHeadless --startvm ${VMName} "
    Execute-Command -command "VBoxManage sharedfolder add $sshPath -name ".ssh" -hostpath $sshPath"
}

Clear-Host
###
### Prompt for VM Platform
$title = "Virtual Machine Options"  
$question = '
    This script supports two 3rd party virtualization options.
    - VMWare Workstation Player (default)
    - Oracle Virtual Box
    '

$options=@(
    ("&1 vmware","1"),
    ("&2 oraclevbox","2"),
    #("&hyperv","hyperv"),
    ("&Quit","Quit")
) | % { New-Object System.Management.Automation.Host.ChoiceDescription $_ }

$choices=[System.Management.Automation.Host.ChoiceDescription[]]($options)

$decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)

switch ($decision)
{
    0 {
        $sys = "vmware-workstation-player"
        break
      };
    1 { 
        $sys = "virtualbox"
        break
        };
    2 {
        $sys = "hyperv"
        break
      };
    3 {Exit}
}

Install-ChocoPackage -PackageName $sys

Clear-Host
#Prompt for Version
$title = "NixOS Versions"  
$question = '
    Which version of NixOS do you want? 
    '

$options=@(
    ("&1. gnome_x86_64", "gnome_x86_64"),
    ("&2. gnome_aarch64"),
    ("&3. kde_x86_64"),
    ("&4. kde_aarch64"),
    ("&5. minimal_x86_64"),
    ("&6. minimal_aarch64"),
    ("&Quit")
    ) | % { New-Object System.Management.Automation.Host.ChoiceDescription $_ }

$choices=[System.Management.Automation.Host.ChoiceDescription[]]($options)

$decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)

switch ($decision)
{
    0 {
        $nixFlavor = "gnome-x86_64-linux.iso"
        break
      };
    1 { 
        $nixFlavor = "gnome-aarch64-linux.iso"
        break
        };
    2 {
        $nixFlavor = "plasma5-x86_64-linux.iso"
        break
      };
    3 {
        $nixFlavor = "plasma5-aarch64-linux.iso"
        break
      };
    4 {
        $nixFlavor = "minimal-x86_64-linux.iso"
        break
      };
    5 {
        $nixFlavor = "minimal-aarch64-linux.iso"
        break
      };
    6 {
        {Exit}
      };
}



write-host "Downloading NixOS."
Invoke-WebRequest "https://channels.nixos.org/${NixPackageVersion}latest-nixos-$nixFlavor" -OutFile nixos.iso

write-host "Process Completed."

buildVirtualBoxImage $VName $VMPath