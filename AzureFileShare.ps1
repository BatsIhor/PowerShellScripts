$ctx=New-AzureStorageContext <StorageAcc> key==

try {
    $share = Get-AzureStorageShare webfileshare -Context $ctx

    if($share -eq $null)
    {
        $share = New-AzureStorageShare webfileshare -Context $ctx
    }
    New-AzureStorageDirectory -Share $share -Path Images -ErrorAction SilentlyContinue
    New-AzureStorageDirectory -Share $share -Path IDP -ErrorAction SilentlyContinue
}
catch {
    Write-Warning $_
}


$driveLeter = 'S'
if (([System.IO.DriveInfo]("$driveLeter")).Drivetype -eq 'NoRootDirectory') {
	Write-Host "Mapping web file share: $((Get-Date).ToString())"
	net use ${driveLeter}: \\<StorageAcc>.file.core.windows.net\webfileshare /u:<StorageAcc> key== /Persist:YES
}
