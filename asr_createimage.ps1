Param(
    [parameter(Mandatory=$true)]
    $CsvFilePath
)

$ErrorActionPreference = "Stop"

$scriptsPath = $PSScriptRoot
if ($PSScriptRoot -eq "") {
    $scriptsPath = "."
}

. "$scriptsPath\asr_logger.ps1"
. "$scriptsPath\asr_common.ps1"
. "$scriptsPath\asr_csv_processor.ps1"

Function ProcessItemImpl($processor, $csvItem, $reportItem) {
    $reportItem | Add-Member NoteProperty "imagecreatejob" $null

    $vaultName = $csvItem.VAULT_NAME
    $sourceMachineName = $csvItem.SOURCE_MACHINE_NAME
    $sourceVMMServer = $csvItem.VMM_SERVER
    $targetTestFailoverVNET = $csvItem.TESTFAILOVER_VNET
    $targetTestFailoverRG = $csvItem.TARGET_RESOURCE_GROUP
    $targetTestFailoverVM = $csvItem.TARGET_MACHINE_NAME+"-test"

    $protectedItem = $asrCommon.GetProtectedItemFromVault($vaultName, $sourceMachineName, $sourceVMMServer)
    if ($protectedItem -ne $null) {
            $processor.Logger.LogTrace("Starting Create VM loop instructions for item '$($sourceMachineName)'")

            $processor.Logger.LogTrace("Stopping '$($sourceMachineName)'")
            Stop-AzVM -ResourceGroupName $targetTestFailoverRG -Name $targetTestFailoverVM -Force
            $processor.Logger.LogTrace("Marking VM as generalized '$($sourceMachineName)'")
            Set-AzVm -ResourceGroupName $targetTestFailoverRG -Name $targetTestFailoverVM -Generalized
            
            $vm = Get-AzVM -Name $targetTestFailoverVM -ResourceGroupName $targetTestFailoverRG
            
            $image = New-AzImageConfig -Location $vm.location -SourceVirtualMachineId $vm.Id -ZoneResilient
            $imageName = "img-"+$csvItem.TARGET_MACHINE_NAME
            
            $processor.Logger.LogTrace("Will create image from'$($sourceMachineName)' to '$($imagename)' in '$($vm.location)' ") 

            $imagecreatejob = New-AzImage -Image $image -ImageName $imageName -ResourceGroupName $targetTestFailoverRG

            $reportItem.imagecreatejob = $imagecreatejob.ID
        }
    
    }

Function ProcessItem($processor, $csvItem, $reportItem)
{
    try {
        ProcessItemImpl $processor $csvItem $reportItem
    }
    catch {
        $exceptionMessage = $_ | Out-String
        $processor.Logger.LogError($exceptionMessage)
        throw
    }
}

$logger = New-AsrLoggerInstance -CommandPath $PSCommandPath
$asrCommon = New-AsrCommonInstance -Logger $logger
$processor = New-CsvProcessorInstance -Logger $logger -ProcessItemFunction $function:ProcessItem
$processor.ProcessFile($CsvFilePath)

