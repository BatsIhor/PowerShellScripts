param(
    [Parameter(Mandatory = $true)] 
    [string]$FileName,
    [Parameter(Mandatory = $true)] 
    [string]$FileLocation
)

function ExitWithExitCode 
{ 
    param 
    ( 
        $ExitCode 
    ) 

    $host.SetShouldExit($ExitCode) 
    exit 
}

function InstallOctopusDSC 
{ 
  if (-not (Test-Path "C:\Program Files\WindowsPowerShell\Modules\OctopusDSC")) {
		mkdir c:\temp -ErrorAction SilentlyContinue | Out-Null
		$client = new-object system.Net.Webclient
		$client.DownloadFile("https://urlTo/OctopusDSC.zip","c:\temp\octopusdsc.zip")
		Add-Type -AssemblyName System.IO.Compression.FileSystem
		[System.IO.Compression.ZipFile]::ExtractToDirectory("c:\temp\octopusdsc.zip", "c:\temp")
		cp -Recurse C:\temp\OctopusDSC\OctopusDSC "C:\Program Files\WindowsPowerShell\Modules\OctopusDSC"
	}
}

function ConfigureOctopus
{ 
    Import-DscResource -Module OctopusDSC

    Node "localhost"
    {
        cTentacleAgent OctopusTentacle
        {
            Ensure = "Present";
            State = "Started";

            # Tentacle instance name. Leave it as 'Tentacle' unless you have more
            # than one instance
            Name = "Tentacle";

            # Registration - all parameters required
            ApiKey = "API-";
            OctopusServerUrl = "IP.Add.Ress.:8081";
            Environments = "QA";
            Roles = "Report";

            # Optional settings
            ListenPort = "10933";
            DefaultApplicationDirectory = "C:\Deployment"
			tentacleDownloadUrl = "http://octopusdeploy.com/downloads/latest/OctopusTentacle";
			tentacleDownloadUrl64 = "http://octopusdeploy.com/downloads/latest/OctopusTentacle64";	
        }
    }
} 


function Tentacle-Configure([string]$arguments)
{
	Write-Output "Configuring Tentacle with $arguments"

	$pinfo = New-Object System.Diagnostics.ProcessStartInfo
	$pinfo.FileName = "C:\Program Files\Octopus Deploy\Tentacle\Tentacle.exe"
	$pinfo.RedirectStandardError = $true
	$pinfo.RedirectStandardOutput = $true
	$pinfo.CreateNoWindow = $true; 
	$pinfo.UseShellExecute = $false;
	$pinfo.UseShellExecute = $false
	$pinfo.Arguments = $arguments
	$p = New-Object System.Diagnostics.Process
	$p.StartInfo = $pinfo
	$p.Start() | Out-Null
	$p.WaitForExit()
	$stdout = $p.StandardOutput.ReadToEnd()
	$stderr = $p.StandardError.ReadToEnd()
	
	Write-Host $stdout
	Write-Host $stderr
	
	if ($p.ExitCode -ne 0) {
		Write-Host "Exit code: " + $p.ExitCode
		throw "Configuration failed"
	}
}

if ($FileLocation.EndsWith('/'))
{
    $zipfilesource = "$FileLocation$FileName"
}
else
{
    $zipfilesource = "$FileLocation/$FileName"
}

try
{
    Import-Module ServerManager
    Install-WindowsFeature web-server,web-common-http,web-app-dev,web-asp-net45,web-appinit

    $guid=[system.guid]::NewGuid().Guid
    $folder="$env:temp\$guid"
    New-Item -Path $folder -ItemType Directory

    $zipfilelocal = "$folder\$filename"
    $zipextracted="$folder\extracted"

    Invoke-WebRequest $zipfilesource -OutFile $zipfilelocal

    Add-Type -assembly "system.io.compression.filesystem"
    [io.compression.zipfile]::ExtractToDirectory($zipfilelocal, $zipextracted)

    copy-item $zipextracted\* c:\inetpub\wwwroot -Force -Recurse
	
	#InstallOctopusDSC
	$serverThumbprint = "FBEAF4515801475D23D3ADEDCCC93782F796C020"
	$serverUri = "http://IP.ADD.RESS:8081"
	$tentacleInstallApiKey = "API-"
	$role = "Report, DB"
	$environment = "QA"
	
	Write-Output "Beginning Tentacle installation"

	Write-Output "Downloading Octopus Tentacle MSI..."
	[System.Net.ServicePointManager]::Expect100Continue = $true;
	[System.Net.ServicePointManager]::SecurityProtocol = `
	[System.Net.SecurityProtocolType]::Ssl3 -bor `
	[System.Net.SecurityProtocolType]::Tls -bor `
	[System.Net.SecurityProtocolType]::Tls11 -bor `
	[System.Net.SecurityProtocolType]::Tls12

	$downloader = new-object System.Net.WebClient
	$downloader.DownloadFile("https://octopus.com/downloads/latest/OctopusTentacle64", "Tentacle.msi")

	Write-Output "Installing Tentacle"
	$msiExitCode = (Start-Process -FilePath "msiexec.exe" -ArgumentList " /i Tentacle.msi /quiet" -Wait).ExitCode
	#if ($msiExitCode -ne 0) {
	#    Write-Output "Tentacle MSI installer returned exit code $msiExitCode"
	#    throw "Installation aborted"
	#}

    $ipAddress =((ipconfig | findstr [0-9].\.)[0]).Split()[-1]
	Write-Output "Detected IP address as $ipAddress"

	Write-Output "Configuring Tentacle"
	Tentacle-Configure "create-instance --instance `"Tentacle`" --config `"C:\Octopus\Tentacle.config`" --console"
	Tentacle-Configure "new-certificate --instance `"Tentacle`" --if-blank --console"
	Tentacle-Configure "configure --instance `"Tentacle`" --reset-trust --console"
	Tentacle-Configure "configure --instance `"Tentacle`" --home `"C:\Octopus`" --app `"C:\Octopus\Applications`" --port `"10933`" --console"
	Tentacle-Configure "configure --instance `"Tentacle`" --trust `"$serverThumbprint`" --console"
	netsh advfirewall firewall add rule "name=Octopus Deploy Tentacle" dir=in action=allow protocol=TCP localport=10933
	Tentacle-Configure "register-with --instance `"Tentacle`" --server `"$serverUri`" --apiKey=`"$tentacleInstallApiKey`" --publicHostName $ipAddress --role `"$role`" --environment `"$environment`" --comms-style TentaclePassive --console"
	Tentacle-Configure "service --instance `"Tentacle`" --install --start --console"

	Write-Output "Installation Tentacle"

	Remove-Item "Tentacle.msi"
	Remove-Item $PSCommandPath
	#ConfigureOctopus
	
    ExitWithExitCode -ExitCode 0
}
catch
{
    Write-Error $_
    ExitWithExitCode -ExitCode 1
}