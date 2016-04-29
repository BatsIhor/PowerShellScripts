<#
.SYNOPSIS
   Modifies some Azure cscfg entries that Octopus Deploy 2.0 is not able to as of today.
.DESCRIPTION
   Sets the thumbprint of the first certificate value. Sets the instance count for each role. Octopus-variables must match either of the two forms:
   Azure.Role[rolename].Instances
   Azure.Role[rolename].Certificate
   where rolename is the roleName as defined in the ServiceConfiguration.Cloud.csfcg.
   The config file must be named ServiceConfiguration.Cloud.cscfg.
#>

$configFile = "ServiceConfiguration.Cloud.cscfg";
Write-host "Updating config file named" $configFile "for with instance and certificate values"
Write-host ""

$OctopusVariablesRegex = @{ 	
	AzureRoleInstancesVariable = "Azure.Role\[(?<roleName>[^\]]+)\]\.Instances";
	AzureRoleCertificateVariable = "Azure.Role\[(?<roleName>[^\]]+)\]\.Certificate";
}

function GetCustomRoleInfoFromOctopusParameters(){
	Write-host "Checking Octopus variables for the variables on format:"
	Write-host "* Azure.Role[roleName].Instances"
	Write-host "* Azure.Role[roleName].Certificate"
	Write-host ""
	
	$roleInstancesVariables = @{}
	$roleCertificatesVariables = @{}		
	
	foreach ($objItem in $OctopusParameters.Keys) {		
		
		$isInstancesVariableByName = $objItem -match $OctopusVariablesRegex.AzureRoleInstancesVariable
		
		if($isInstancesVariableByName){
			$roleName = $matches.roleName
			$roleInstancesVariables[$roleName] = $OctopusParameters[$objItem]			
		}
		
		
		$isCertificateVariable = $objItem -match $OctopusVariablesRegex.AzureRoleCertificateVariable
		if($isCertificateVariable){
			$roleName = $matches.roleName
			$roleCertificatesVariables[$roleName] = $OctopusParameters[$objItem]
		}
	}
	
	$roleInfo = @{ Instances = $roleInstancesVariables; Certificates = $roleCertificatesVariables}	
	Write-host "Found" $roleInstancesVariables.Keys.count "roles for instance update"
	Write-host "Found" $roleCertificatesVariables.Keys.count "roles for certificate update"	
	Write-host ""
	return $roleInfo
}

function ParseAzureConfigToXml(){

	if(!(test-path $configFile)){		
		WriteErrorMsg "Could not find ServiceConfig file named '$configFile'!"
		Exit 1
	}
		
	[xml]$configFileAsXml = Get-Content $configFile
	return $configFileAsXml;
}

function UpdateFirstCertificateEntriesForEveryRole($xmlToBeUpdated, $certificatesForRoles) {
	
	foreach ($roleName in $certificatesForRoles.Keys) {
		$role = GetRole $xmlToBeUpdated $roleName	
		
		if($role.Certificates -eq $null){
			WriteErrorMsg "Role did not have defined Certificates section! Could not update first certificate value!"
			Exit 1
		}		
		Write-host "Updating Certificate named" $role.Certificates.Certificate[1].name "for" $role.name
		$role.Certificates.Certificate[1].thumbprint = [string]$certificatesForRoles[$roleName];
	}
	return $xmlToBeUpdated
}

function UpdateInstanceCounts($xmlToBeUpdated, $instancesForRoles){
	
	foreach ($roleName in $instancesForRoles.Keys) {
		$role = GetRole $xmlToBeUpdated $roleName
	
		$newInstanceCount = $instancesForRoles[$roleName]
		$isInteger = IsIntegerValue $newInstanceCount
		if($isInteger -eq $false){
			WriteErrorMsg "Instance count update failed: Instance count for '$roleName' in Octopus variable is not an integer";
			Exit 1
		}
		Write-host "Updating instance count for role" $role.name "to" $instancesForRoles[$roleName]
		$role.Instances.count = $instancesForRoles[$roleName];
	}
	return $xmlToBeUpdated
}

function IsIntegerValue($val){	
	if($val -match "^[0-9]+$"){
		return $true
	}
	return $false
}

function GetRole($xml, $roleName){	
	$role = $xml.ServiceConfiguration.Role  | Where-Object {$_.name -eq $roleName }
	if($role -eq $null){			
		WriteErrorMsg "Could not find a role named '$roleName' in ServiceConfig";
		Exit 1
	}
	return $role
}

function WriteErrormsg($msg){
	Write-host "**** Could not update the ServiceConfiguration file! Error:." $msg
}

$roleInfo = GetCustomRoleInfoFromOctopusParameters
$xml = ParseAzureConfigToXml
$xmlWithNewCertificate = UpdateFirstCertificateEntriesForEveryRole $xml $roleInfo.Certificates
$xmlWithNewInstanceCounts = UpdateInstanceCounts $xmlWithNewCertificate $roleInfo.Instances
$xmlWithNewInstanceCounts.Save($configFile);
Write-host ""
Write-host "ServiceConfiguration.Cloud.cscfg updated!"