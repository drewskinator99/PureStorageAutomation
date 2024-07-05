Import-Module  PureStoragePowerShellSDK2 
$Error.clear()
# Set filepaths
$todaylog = Get-Date -Format "_MM_dd_yy"
$logFilePath = "\\server.domain.local\C`$\Path\Logs\PureAutomationLog_$todaylog.txt"
$logfolderPath = "\\server.domain.local\C`$\Path\Logs"
$timestamp = Get-Date -Format "MM/dd/yyyy HH:mm"

# connection to Pure - Credentials
$User = "username"
$PasswordFile = "\\server.domain.local\C`$\Path\Pauto.txt"
$KeyFile = "\\server.domain.local\C`$\Path\AES.key"
$key = Get-Content $KeyFile
$MyCredential = New-Object -TypeName System.Management.Automation.PSCredential `
 -ArgumentList $User, (Get-Content $PasswordFile | ConvertTo-SecureString -Key $key)
$EndPoint = "pure-server.domain.local"

# Pure volumes
$sourcevolumes = @('vvol-sourcevolume-something')
Write-Output "$timestamp > Starting the Snapshot Deletion Script..." >> $logFilePath
foreach($sourcevolume in $sourcevolumes){
    try{
       $FlashArray2 = Connect-Pfa2Array -EndPoint $EndPoint -Credential $MyCredential -IgnoreCertificateError
    }
    catch{
        Write-Output "$timestamp >  Issues connecting to Pure. Exiting." >> $logFilePath
        if($Error.Count){
            Write-Output "$timestamp > Errors:`n`n $Error`n`n" >> $logFilePath
        }
        exit 401
    }
    try{
        $MostRecentSnapshot = Get-Pfa2VolumeSnapshot -Array $FlashArray2   | Where-Object{$_.name -like "*$sourcevolume.PureAutomation"}| Sort-Object Created -Descending | Select-Object -First 1
    }
    catch{
        if($Error.Count){
            Write-Output "$timestamp > Errors:`n`n $Error`n`n" >> $logFilePath
            exit 401
        }
    }

    if($MostRecentSnapshot){
        $name = $MostRecentSnapshot.Name
        Write-Output "$timestamp > Snapshot found: $name" >> $logFilePath
    }
    else{
         Write-Output "$timestamp > No snapshot found." >> $logFilePath
         if($Error.Count){
            Write-Output "$timestamp > Errors:`n`n $Error`n`n" >> $logFilePath
         }
         exit 401
    }
    if($name){
        try{

            Update-Pfa2VolumeSnapshot -Array $Array2 -Destroyed $true -Name $name -ErrorAction Stop
        }
        catch{
            if($Error.Count){
                Write-Output "$timestamp > Errors:`n`n $Error`n`n" >> $logFilePath
                exit 401
            }
        }
    }
    else{
        Write-Output "$timestamp > Did not find the snapshot to delete: $name" >> $logFilePath
        if($Error.Count){
                Write-Output "$timestamp > Errors:`n`n $Error`n`n" >> $logFilePath
                exit 401
            }
    }
    Write-Output "$timestamp >  Successfully Destroyed Snapshot $name" >> $logFilePath
    if((Get-Pfa2VolumeSnapshot -Array $FlashArray2   | Where-Object{$_.name -like "*$sourcevolume.PureAutomation"}| Sort-Object Created -Descending | Select-Object -First 1).Destroyed){
            try{
                Get-Pfa2VolumeSnapshot -Array $FlashArray2 -Name $name | Remove-Pfa2VolumeSnapshot -Eradicate -Confirm:$false -ErrorAction Stop
            }
            catch{
                if($Error.Count){
                    Write-Output "$timestamp > Errors:`n`n $Error`n`n" >> $logFilePath
                    exit 401
                }    
            }
            if(Get-Pfa2VolumeSnapshot -Array $FlashArray2   | Where-Object{$_.name -like "*$sourcevolume.PureAutomation"}| Sort-Object Created -Descending | Select-Object -First 1){
                #error
                 Write-Output "$timestamp >  Could not delete snapshot $name" >> $logFilePath
                if($Error.Count){
                    Write-Output "$timestamp > Errors:`n`n $Error`n`n" >> $logFilePath
                    exit 401
                }
            }
            else{
                #success
                Write-Output "$timestamp >  Successfully Eradicated Snapshot $name" >> $logFilePath
            }
    }
    else{
        #error
        Write-Output "$timestamp >  Could not eradicate snapshot $name" >> $logFilePath
        if($Error.Count){
            Write-Output "$timestamp > Errors:`n`n $Error`n`n" >> $logFilePath
            exit 401
        }
    }
} 
#### LOG FOLDER CLEANUP ####

$today = Get-Date
$lastDayOfMonth = Get-Date -Day 1 -Month ($today.Month + 1) -Year $today.Year -Hour 0 -Minute 0 -Second 0 -Millisecond 0

if (($today.AddDays(1).Month -ne $today.Month) -and $lastDayOfMonth) {
    Write-Output "$timestamp > Cleaning up Log Folder." >> $logFilePath

    # Today is the last day of the current month
    $cutoffDate = $today.AddDays(-180)
    $filesToDelete = Get-ChildItem -Path $logfolderPath -File | Where-Object { $_.CreationTime -lt $cutoffDate }
    if($filesToDelete -and (Test-Path $logfolderPath)){
        foreach ($file in $filesToDelete) {
            Write-Output "$timestamp > Deleting $($file.Name) created on $($file.CreationTime)" >> $logFilePath
            try{
                Remove-Item -Path $file.FullName -Force -ErrorAction Stop
            }
            catch{
                Write-Output "$timestamp > Error Deleting $($file.Name) created on $($file.CreationTime)" >> $logFilePath
                Write-Output "$timestamp > Errors:`n`n $Error`n`n" >> $logFilePath
                continue                 
                
            }
            Write-Output "Deleting $($file.Name) created on $($file.CreationTime)" >> $logFilePath
        }
    }
}




    
    