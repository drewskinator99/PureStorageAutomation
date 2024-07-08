#####################################################################################
#                                                                                   #                                                                               #
#  PureAutomation-Main: Refreshing SQL with Pure Replication                        #
#                                                                                   #
#     Created by: drewskinator99                                                    #
#     Date: 11/5/2023                                                               #
#                                                                                   # 
#     Description: This script assumes a snapshot of the source drive               # 
#     has already been taken, and will be deleted after the script is run.          # 
#     It will take in a list of strings that represent the names of the disks that  #
#     need to be processed. variable name: $targetvolumelist. the script creates an # 
#     array of objects to iterate through to process the Pure refreshing process.   # 
#     For every object, the script finds the source and target disks, and refreshes #
#     target drive with the source drive using the Pure SDK. Log files are placed   #
#     at a location of your choosing. the script assumes the disk that is being     #  
#     refreshed already exists. The drives and volumes are re-labeled and re-named. #
#                                                                                   #
#     Options for Drives: R_Instance, S_Instance, D_Instance, L_Instance          # 
#                                                                                   # 
#     HOW TO USE:                                                                   #
#          .\PureAutomation-main.ps1 -targetvolumelist @("R_Instance","S_Instance") #
#                                                                                   #
#     Task Action: Executed through SQL jobs with local system privelages           #
#                                                                                   # 
#####################################################################################
<#
.SYNOPSIS

.DESCRIPTION
Long description

.PARAMETER targetvolumeList
Parameter description

.PARAMETER sourcevolumeList
Parameter description

.PARAMETER logFilepath
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
##############################################################################################################
#
# The purpose of this function is to create an array of objects that contain the attributes needed
#    to loop through each SQL instance and refresh the target volume with the source snapshot.
#    An array of objects are returned, and null is returned on error. If the target volume is not 
#    found based on the search criteria, it will print to the log file and skip it. The search criteria
#    will be strings assigned by script parameters that the sql code will set.
#
############################################################################################################
function PureAutomation-CreateObjects{
    [cmdletbinding()]param(
    [Parameter(Mandatory=$true)][string[]] $targetvolumeList,
    [Parameter(Mandatory=$true)][string[]] $sourcevolumeList,
    [Parameter(Mandatory=$true)][string] $logFilepath
    )
    $timestamp = Get-Date -Format "MM/dd/yyyy HH:mm"
    $tcount = $targetvolumeList.Count
    $scount =  $sourcevolumeList.Count
    if(!($tcount -eq $scount)){
        Write-Output "$timestamp >  [ERROR] in Create Objects Function. Source Count Doesn't Match Destination Count. Exiting." >> $logFilePath
        return $null
    }  
    [int]$i = [int]0
    $volumeObjectArray = @()
    foreach($item in $targetvolumeList){
        $driveLetter = $null
        $targvolNum = $null
        $srcvolname = $sourcevolumeList[$targetvolumeList.IndexOf($item)]    
        if($item -like "R_Instance"){
            $targetvolname = 'vvol-Name-Something-vg/Data-VolName'
            $identifier = 'R_Instance'
            $driveLetter = 'R'
            
        }
        elseif($item -like "D_Instance"){
            #$targetvolname = ''
            $identifier = 'D_Instance'
            $driveLetter = 'E'
        }
        elseif($item -like "S_Instance"){
            $targetvolname = 'vvol-Name-Something-vg/Data-VolName'
            $identifier = 'S_Instance'
            $driveLetter = 'S'
        }
        elseif($item -like "L_Instance"){
            #$targetvolname = ''           
            $identifier = 'L_Instance'
            $driveLetter = 'L'
        }
        else{
            # print Error message
            $logmessage = "$timestamp >  [ERROR] in Create objects function. Input Chosen is not Valid. Item chosen: $item"
            Add-Content -path $logFilePath -value $logmessage
            continue
        }
        if($driveletter -eq $null){
            $logmessage = "$timestamp >  [ERROR] in Create objects function. Drive Letter is null"
            Add-Content -path $logFilePath -value $logmessage
            continue
        }
        $targvolNum = (Get-Volume | Where-Object {$_.DriveLetter -eq $driveletter} | Get-Partition | get-Disk ).Number
        if($targvolNum  -eq $null){
            $logmessage = "$timestamp >  [ERROR] in Create objects function. Drive Number is null"
            Add-Content -path $logFilePath -value $logmessage
            continue
        }
        # Create a custom object to store the extracted variables
        $volumeObject = [PSCustomObject]@{
            Identifier = $identifier
            SourceVolumeName = $srcvolname
            TargetVolumeName = $targetvolname
            Index = [int]$i
            TargetDeviceNumber = $targvolNum
            DriveLetter = $driveLetter
            FileSystemLabel = $identifier    
        }
        $i++
        $volumeObjectArray += $volumeObject
    }
    return $volumeObjectArray
 }

####################################################################################################
#
# The purpose of this function is to create an array of source volume names that will allow for a 
#    1-1 mapping of the same source volume, for different target volumes. the function relies on the
#    count of target volumes as a parameter to initialize and return the array. The source and target
#    array sizes should always be the same in the main function it returns to.
#
#
####################################################################################################
function PureAutomation-InitSourceArray{
    [cmdletbinding()]param(
    [Parameter(Mandatory=$true)][int] $count,
    [Parameter(Mandatory=$true)][string[]] $sourcetarget,
    [Parameter(Mandatory=$true)][string] $logFilepath  
    )
    if($count -lt 1){
        return $null
    }
    $sourcearray = @()
    $i = 0
    for($i=0; $i -lt $count; $i++){
        $sourcearray += $sourcetarget
    }
    return $sourcearray
}
####################################################################################################
#
#
#      MAIN FUNCTION
#
#
####################################################################################################
####### SECTION 1: Variales ########################################################################
[Parameter(Mandatory=$true)][string[]] $targetvolumelist 
import-Module PureStorage.FlashArray.VMWare
$Error.clear()
$todaylog = Get-Date -Format "_MM_dd_yy"
$logFilePath = "\\server.domain.local\C`$\Path\Logs\PureAutomationLog_$todaylog.txt"
$timestamp = Get-Date -Format "MM/dd/yyyy HH:mm"
####### SECTION 2: Pre-requisite Checks ###########################################################
# Error Checking
$targetcount = $targetvolumelist.Count
if(!$targetcount){
    $logmessage = "$timestamp >  [ERROR] in Main function. User did not provide any arguments for the target volume list.  Exiting." 
    Add-Content -path $logFilePath -value $logmessage
    exit -1

}
######## SECTION 3 - PURE API CONNECTION #########################################################
# Connection to Pure 
$User = "username"
$PasswordFile = "\\server\c`$\Path\Pauto.txt"
$KeyFile = "\\server\c`$\Path\AES.key"
$key = Get-Content $KeyFile
$MyCredential = New-Object -TypeName System.Management.Automation.PSCredential `
    -ArgumentList $User, (Get-Content $PasswordFile | ConvertTo-SecureString -Key $key)
$EndPoint = "pure-server.domain.local"
try{
    $FlashArray = New-PfaArray -EndPoint $EndPoint  -Credentials $MyCredential -IgnoreCertificateError -ErrorAction Stop
    $FlashArray2 = Connect-Pfa2Array -EndPoint $EndPoint -Credential $MyCredential -IgnoreCertificateError -ErrorAction Stop
}catch{
    $logmessage = "$timestamp >  [ERROR] in Main function while attempting to connect to Pure's Array via the API. Exiting." 
    Add-Content -path $logFilePath -value $logmessage
    if($Error.Count){       
        $logmessage = "Errors:`n`n $Error`n`n" 
        Add-Content -path $logFilePath -Value $logmessage
    }
    exit -2
}   
$logmessage = "$timestamp >  [SUCCESS] in Main function. Connected to Pure's Array via the API." 
Add-Content -path $logFilePath -value $logmessage
######## SECTION 4: CREATE SOURCE VOLUMES ARRAY #################################################
# Setup Source and Target Volume Arrays
$sourcetarget = 'Source-Clone-VVol/Data-Something'
$sourcevolumelist = @()
$sourcevolumelist = PureAutomation-InitSourceArray -count $targetcount -sourcetarget $sourcetarget -logFilepath $logFilePath
$sourcevolumelist 
if(($sourcevolumelist -eq $null) -or ($sourcevolumelist.Count -eq 0)){
    # ERROR
    $logmessage = "$timestamp >  [ERROR] in Main function. Source volume list initialized empty. Target array size: $targetcount" 
    Add-Content -path $logFilePath -value $logmessage
    if($Error.Count){       
        $logmessage = "Errors:`n`n $Error`n`n" 
        Add-Content -path $logFilePath -Value $logmessage
    }
    exit -3
}
######### SECTION 5: Create Objects to loop through ############################################
# Create Objects to Iterate through and perform Pure Refreshes on
$PureAutomationObjects = PureAutomation-CreateObjects -sourcevolumelist $sourcevolumelist -targetvolumelist $targetvolumelist -logFilePath $logFilePath
$PureAutomationObjects
if($PureAutomationObjects -eq $null){
    # ERROR
    $logmessage = "$timestamp >  [ERROR] in Main function. CreateObjects function returned an empty array." 
    Add-Content -path $logFilePath -value $logmessage
    if($Error.Count){       
        $logmessage = "Errors:`n`n $Error`n`n" 
        Add-Content -path $logFilePath -Value $logmessage
    }
    exit -4
}
################################## FOR EACH INSTANCE: #############################################
foreach($PureObj in $PureAutomationObjects){ 
    $targetdeviceNumber = $PureObj.TargetDeviceNumber
    $sourcevolumeName = $PureObj.SourceVolumeName
    $targetvolumeName = $PureObj.TargetVolumeName
    $PureObj.Index
    $driveletter = $PureObj.DriveLetter
    $filesystemlabel = $PureObj.FileSystemLabel
    $size = [math]::Round((Get-Volume | Where-Object {$_.DriveLetter -eq $driveletter} | Get-Partition | get-Disk | select size).size/1000000000000)
    ############################  LOOP -> OFFLINE DISKS    ####################################                         
    Write-Output "$timestamp > [INFO] Offlining Disk: $($driveletter) of size $($size)TB" >> $logFilePath
    $disk = Get-Volume | Where-Object {$_.DriveLetter -eq $driveletter} | Get-Partition | Get-Disk 
    $disknumber = $disk.DiskNumber
    if(!$disk){
        Write-Output "$timestamp >  [ERROR] in main function Issues Geting Disk and setting offline. Exiting." >> $logFilePath
        if($Error.Count){
            Write-Output "$timestamp > Errors:`n`n $Error`n`n" >> $logFilePath
        }
        continue
    }
    try{
        $disk | Set-Disk -IsOffline $True -ErrorAction Stop
    }
    catch{
        Write-Output "$timestamp >  [ERROR] in main function. Issues Geting Disk and setting offline. Continuing." >> $logFilePath
        if($Error.Count){
            Write-Output "$timestamp > Errors:`n`n $Error`n`n" >> $logFilePath
        }
        continue
    }
    Start-Sleep -Seconds 5
    $status = (Get-Disk  | Where-object {$_.Number -eq $disknumber} | select OperationalStatus).OperationalStatus
    $count = 0
    while(!($status -eq "Offline") -and !($count -gt 9)){
        Write-Output "$timestamp > [WARNING] Disk is still online. trying again." >> $logFilePath
        Start-Sleep -Seconds 2
        try{
            $disk | Set-Disk -IsOffline $True -ErrorAction Stop
        }
        catch{
            Write-Output "$timestamp >  [ERROR] in main function. Issues Geting Disk and setting offline. Exiting." >> $logFilePath
            if($Error.Count){
                Write-Output "$timestamp > Errors:`n`n $Error`n`n" >> $logFilePath
            }
            continue
        }    
        $status = (Get-Disk  | Where-object {$_.Number -eq $disknumber} | select OperationalStatus).OperationalStatus
        $count++                
    } # end of while loop
    if($status -eq "Offline"){
        Write-Output "$timestamp > [SUCCESS] Disk Successfully went offline." >> $logFilePath
    }
    else{
        Write-Output "$timestamp > [ERROR] in main function. Disk never went offline." >> $logFilePath
        continue
    }    
    #####################   LOOP -> REPLACE TARGET VOLUME WITH SOURCE SNAPSHOT #######################
    try{
        $querystr = $sourcevolumeName + ".PureAutomation"
        $volume = Get-Pfa2Volume -Array $FlashArray2 | Where-Object { $_.name -like $sourcevolumeName }
        $volname = $volume.name
        $snapshot = Get-Pfa2VolumeSnapshot -Array $FlashArray2   | Where-Object{$_.name -like $querystr}
        $snapshotname = $snapshot.Name
        Write-Output "$timestamp > [INFO] Source snapshot name: $snapshotname" >> $logFilePath
    }
    catch{
        Write-Output "$timestamp > [ERROR] in main funciton while Finding target pure storage array volume" >> $logFilePath
        if($Error.Count){
            Write-Output "$timestamp > Errors:`n`n $Error`n`n" >> $logFilePath           
         }
         continue
    }
    if(!$volume -or !$volname -or !$snapshotname){
        Write-Output "$timestamp > [ERROR] in main function Finding volume and/or snapshot." >> $logFilePath
        if($Error.Count){
            Write-Output "$timestamp > Errors:`n`n $Error`n`n" >> $logFilePath           
         }
         continue
    }
    try{
        New-PfaRestOperation -ResourceType volume/$($targetvolumeName) -RestOperationType POST -Flasharray $FlashArray -jsonBody "{`"overwrite`":true,`"source`":`"$($snapshotname)`"}"             
    }
    catch{
        Write-Output "$timestamp > [ERROR] in main function replacing Disk on $targetvolumeName" >> $logFilePath
        if($Error.Count){
            Write-Output "$timestamp > Errors:`n`n $Error`n`n" >> $logFilePath    
         }
         continue
    }
    Write-Output "$timestamp > [SUCCESS] Successfully replaced the contents of $targetvolumeName" >> $logFilePath
    Start-sleep -Seconds 2
    ################################## LOOP -> ONLINE THE DISKS ######################################
    $disk =  Get-Disk |Where-Object {$_.OperationalStatus -eq "Offline" -and $_.Number -eq $disknumber} 
    $size = [math]::Round($disk.AllocatedSize/1000000000000)
    Write-Output "$timestamp > [INFO] Onlining Disk $targetdeviceNumber of size $($size)TB" >> $logFilePath
    try{
        $disk | Set-Disk -IsOffline $false -ErrorAction Stop
    }catch{
        Write-Output "$timestamp > [ERROR] in main function. Issue onlining Disk." >> $logFilePath
        continue
    }
    Write-Output "$timestamp > [INFO] Waiting 10 seconds for the disks to come online..." >> $logFilePath
    Start-Sleep -Seconds 10
    $disk =  Get-Disk |Where-Object {$_.Number -eq $disknumber} 
    $status = ($disk | select OperationalStatus).OperationalStatus
    $count = 0
    while((!($status -eq "Online") -and !($count -gt 9)) -or !($status)){
        Write-Output "$timestamp > [WARNING] Disk is not online. trying again." >> $logFilePath
        Start-Sleep -Seconds 2        
        try{
            $disk | Set-Disk -IsOffline $false -ErrorAction Stop
        }catch{
            Write-Output "$timestamp > [ERROR] Issue onlining Disk." >> $logFilePath
            if($Error.Count){
                Write-Output "$timestamp > Errors:`n`n $Error`n`n" >> $logFilePath
            }
            continue
        }       
        $status = (Get-Disk  | Where-object {$_.Number -eq $disknumber} | select OperationalStatus).OperationalStatus
        $count++
    } # end of while loop
    if($status -eq "Online"){
        Write-Output "$timestamp > [SUCCESS] Disk Successfully came online." >> $logFilePath
    }
    else{
        Write-Output "$timestamp > [ERROR] in main function. Disk never came online." >> $logFilePath
    }
    $drive = Get-WmiObject -Class win32_volume | Where-Object {$_.label -eq  "DATA" -or $_.label -eq  $filesystemlabel}
    $dletter = $drive.DriveLetter.Replace(":", "")
    $vol = Get-Volume -DriveLetter $dletter 
    if(!$vol){
       Write-Output "$timestamp > [ERROR] in Main function finding the volume to rename it." >> $logFilePath
        if($Error.Count){
            Write-Output "$timestamp > Errors:`n`n $Error`n`n" >> $logFilePath        
        }
        continue 
    } 
            #################### LOOP -> RENAME THE DRIVE AND FILE SYSTEM LABEL ##################################
    try{
        Get-Partition -DiskNumber $targetdeviceNumber -PartitionNumber 2 -ErrorAction stop | Set-Partition  -NewDriveLetter $driveletter -ErrorAction Stop
        
    }
    catch{
        Write-Output "$timestamp > [ERROR] in main function remapping drive letter $driveletter to disk number $targetdeviceNumber" >> $logFilePath
        if($Error.Count){
            Write-Output "$timestamp > Errors:`n`n $Error`n`n" >> $logFilePath        
        }
        continue
    }
    try{
        
        Set-Volume -DriveLetter $driveletter -NewFileSystemLabel $filesystemlabel -ErrorAction Stop
    }
    catch{
        Write-Output "$timestamp > [ERROR] in main function renaming Drive $($driveletter): to label $filesystemlabel " >> $logFilePath
        if($Error.Count){
            Write-Output "$timestamp > Errors:`n`n $Error`n`n" >> $logFilePath        
        }
        continue
    }
    Write-Output "$timestamp > [SUCCESS] in main function. Renamed Drive $($driveletter): to $filesystemlabel" >> $logFilePath
} # End For Loop

Write-Output "$timestamp > [SUCCESS] in main function. Script has finished successfully." >> $logFilePath 
exit 0




