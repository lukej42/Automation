param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory=$true)]
    [string]$StorageAccountName,

    [Parameter(Mandatory=$true)]
    [string]$ContainerName
)

# Authenticate to Azure
Connect-AzAccount -Identity

#Get Storage Account
$storageAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName
$ctx = $storageAccount.Context

#Get all blobs sorted by LastModified descending
$blobs = Get-AzStorageBlob -Container $ContainerName -Context $ctx | 
    Sort-Object -Property LastModified -Descending

#Skip the most recent 10, delete the rest
$blobsToDelete = $blobs | Select-Object -Skip 10

foreach ($blob in $blobsToDelete) {
    Write-Output "Deleting blob: $($blob.Name)"
    Remove-AzStorageBlob -Blob $blob.Name -Container $ContainerName -Context $ctx
}
#Output log
Write-Output "Resource Group: $ResourceGroupName"
Write-Output "Storage Account: $StorageAccountName"
Write-Output "Container: $ContainerName"
Write-Output "Blobs found: $($blobs.Count)"
Write-Output "Blobs to delete: $($blobsToDelete.Count)"