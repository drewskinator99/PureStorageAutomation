$timestamp = Get-Date -Format "MM/dd/yyyy HH:mm"
Import-Module  PureStoragePowerShellSDK2 
$Error.clear()
# Set filepaths

$todaylog = Get-Date -Format "_MM_dd_yy"
$logFilePath = "\\server.domain.local\C`$\Path\Logs\PureAutomationLog_$todaylog.txt"
$User = "username"
$PasswordFile = "\\server.domain.local\C`$\Path\Pauto.txt"
$KeyFile = "\\server.domain.local\C`$\Path\AES.key"
$key = Get-Content $KeyFile
$MyCredential = New-Object -TypeName System.Management.Automation.PSCredential `
 -ArgumentList $User, (Get-Content $PasswordFile | ConvertTo-SecureString -Key $key)
# connection to Pure - Credentials
$EndPoint = "pure-server.domain.local"
# Pure volumes
$sourcevolumes = @('vvol-Name-of-Volume/Data-Something')
Write-Output "$timestamp > Starting the Snapshot Creation Script..." >> $logFilePath
try{
    $FlashArray = Connect-Pfa2Array -EndPoint $EndPoint -Credential $MyCredential -IgnoreCertificateError

}catch{
    Write-Output "$timestamp >  Issues connecting to Pure. Exiting." >> $logFilePath
    if($Error.Count){
        Write-Output "$timestamp > Errors:`n`n $Error`n`n" >> $logFilePath
    }
    exit 401
}

foreach($sourcevolume in $sourcevolumes){
    try{
        $volume = Get-Pfa2Volume -Array $FlashArray | Where-Object { $_.name -like $sourcevolume }
        $name = $volume.name
    }
    catch{
        Write-Output "$timestamp > Error finding volume." >> $logFilePath
        if($Error.Count){
            Write-Output "$timestamp > Errors:`n`n $Error`n`n" >> $logFilePath
            exit 401
         }
    }
    try{
     New-Pfa2VolumeSnapshot -Array $FlashArray -SourceName $name -Suffix "PureAutomation" -ErrorAction Stop 
     
    }
    catch{
        Write-Output "$timestamp > Error creating snapshot for $name" >> $logFilePath
        if($Error.Count){
            Write-Output "$timestamp > Errors:`n`n $Error`n`n" >> $logFilePath
            exit 401
         }
    }        
    $MostRecentSnapshot = Get-Pfa2VolumeSnapshot -Array $FlashArray   | Where-Object{$_.name -like "*$sourcevolume.PureAutomation"}| Sort-Object Created -Descending | Select-Object -First 1

    if($MostRecentSnapshot){
        $name = $MostRecentSnapshot.Name
        Write-Output "$timestamp > Snapshot created: $name" >> $logFilePath
    }
    else{
         Write-Output "$timestamp > No snapshot created." >> $logFilePath
         if($Error.Count){
            Write-Output "$timestamp > Errors:`n`n $Error`n`n" >> $logFilePath
         }
         exit 401
    }
 }