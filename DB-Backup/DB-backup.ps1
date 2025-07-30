<#
.OUTPUTS
	Human-readable informational and error messages produced during the job. Not intended to be consumed by another runbook.

#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory=$true)]
    [string]$DatabaseServerName,

    [Parameter(Mandatory=$true)]
    [string]$DatabaseAdminUsername,

    [Parameter(Mandatory=$true)]
    [string]$DatabaseAdminPassword,

    [Parameter(Mandatory=$true)]
    [string]$DatabaseNames,

    [Parameter(Mandatory=$true)]
    [string]$StorageAccountName,

    [Parameter(Mandatory=$true)]
    [string]$BlobStorageEndpoint,

    [Parameter(Mandatory=$true)]
    [string]$StorageKey,

    [Parameter(Mandatory=$true)]
    [string]$BlobContainerName,

    [Parameter(Mandatory=$true)]
    [string]$RetentionDays
)


$ErrorActionPreference = 'stop'

function Login() {
#$connectionName = "AzureRunAsConnection"
try
{
    #$servicePrincipalConnection = Get-AutomationConnection -Name $connectionName         

    Write-Verbose "Logging in to Azure..." -Verbose
    Connect-AzAccount -Identity
    #Add-AzAccount `
    #	-ServicePrincipal `
    #	-TenantId $servicePrincipalConnection.TenantId `
    
    #	-ApplicationId $servicePrincipalConnection.ApplicationId `
    #	-CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint | Out-Null
}
catch {
    Write-Error -Message $_.Exception
    throw $_.Exception
}
}

function Create-Blob-Container([string]$blobContainerName, $storageContext) {
Write-Verbose "Checking if blob container '$blobContainerName' already exists" -Verbose
if (Get-AzStorageContainer -ErrorAction "Stop" -Context $storageContext | Where-Object { $_.Name -eq $blobContainerName }) {
    Write-Verbose "Container '$blobContainerName' already exists" -Verbose
} else {
    New-AzStorageContainer -ErrorAction "Stop" -Name $blobContainerName -Permission Off -Context $storageContext
    Write-Verbose "Container '$blobContainerName' created" -Verbose
}
}

function Export-To-Blob-Storage([string] $RESOURCEGROUPNAME, [string]$databaseServerName, [string]$databaseAdminUsername, [string]$databaseAdminPassword, [string[]]$databaseNames, [string]$storageKey, [string]$blobStorageEndpoint, [string]$blobContainerName) {
Write-Verbose "Starting database export to databases '$databaseNames'" -Verbose
$securePassword = ConvertTo-SecureString –String $databaseAdminPassword –AsPlainText -Force 
$creds = New-Object –TypeName System.Management.Automation.PSCredential –ArgumentList $databaseAdminUsername, $securePassword

foreach ($databaseName in $databaseNames.Split(",").Trim()) {
    Write-Output "Creating request to backup database '$databaseName'"

    $bacpacFilename = $databaseName + (Get-Date).ToString("yyyyMMddHHmm") + ".bacpac"
    $bacpacUri = $blobStorageEndpoint + $blobContainerName + "/" + $bacpacFilename
    $exportRequest = New-AzSqlDatabaseExport -ResourceGroupName $RESOURCEGROUPNAME –ServerName $databaseServerName `
        –DatabaseName $databaseName –StorageKeytype "StorageAccessKey" –storageKey $storageKey -StorageUri $BacpacUri `
        –AdministratorLogin $creds.UserName –AdministratorLoginPassword $creds.Password -ErrorAction "continue"
    
    # Print status of the export
    Get-AzSqlDatabaseImportExportStatus -OperationStatusLink $exportRequest.OperationStatusLink -ErrorAction "Stop"
}
}

function Delete-Old-Backups([int]$retentionDays, [string]$blobContainerName, $storageContext) {
Write-Output "Removing backups older than '$retentionDays' days from blob: '$blobContainerName'"
$isOldDate = [DateTime]::UtcNow.AddDays(-$retentionDays)
$blobs = Get-AzStorageBlob -Container $blobContainerName -Context $storageContext
foreach ($blob in ($blobs | Where-Object { $_.LastModified.UtcDateTime -lt $isOldDate -and $_.BlobType -eq "BlockBlob" })) {
    Write-Verbose ("Removing blob: " + $blob.Name) -Verbose
    Remove-AzStorageBlob -Blob $blob.Name -Container $blobContainerName -Context $storageContext
}
}

Write-Verbose "Starting database backup" -Verbose

$StorageContext = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageKey

Login

Create-Blob-Container `
-blobContainerName $blobContainerName `
-storageContext $storageContext

Export-To-Blob-Storage `
-resourceGroupName $RESOURCEGROUPNAME `
-databaseServerName $DatabaseServerName `
-databaseAdminUsername $DatabaseAdminUsername `
-databaseAdminPassword $DatabaseAdminPassword `
-databaseNames $DatabaseNames `
-storageKey $StorageKey `
-blobStorageEndpoint $BlobStorageEndpoint `
-blobContainerName $BlobContainerName

Write-Verbose "Database backup script finished" -Verbose

