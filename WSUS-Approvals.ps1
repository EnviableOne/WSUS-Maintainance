[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration")
Import-module UpdateServices
Import-module \\PathTo\PatchTuesday\script\Get-PatchTue.psm1
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$Timestamp = (Get-Date).ToString("yyyy-MM-dd_HHmm")
$current = $False #If true select updates since last patch tuesday, if not select update between last two patch tuesdays
$errors = 0

# Find The most recent 2 patch tuesdays
$ToYear = (Get-date).Year
if ((Get-Date) -lt (Get-PatchTue).addHours(18)){
 Switch ((get-date).Month){
  1 {
   $ToMonth = 12
   $ToYear--
   $FromMonth=11
   $FromYear = $ToYear-1
  }
  2 {
   $ToMonth = 1
   $FromMonth = 12
   $FromYear = $ToYear-1
  }
  Default{
   $ToMonth = (get-date).Month -1
   $FromMonth = $ToMonth-1
   $FromYear = $ToYear
  }
 }
}
Else {
 If ((get-date).Month -eq 1){ 
  $ToMonth = (get-date).Month
  $FromMonth = 12
  $FromYear = $ToYear-1
 }
 Else {
  $ToMonth = (get-date).Month
  $FromMonth = $ToMonth-1
  $FromYear = $ToYear
 }
}
$toDate = Get-patchTue -month $ToMonth -year $ToYear
$fromDate = Get-PatchTue -month $FromMonth -year $FromYear

$UpdateScope = New-Object Microsoft.UpdateServices.Administration.UpdateScope
 $UpdateScope.ApprovedStates = [Microsoft.UpdateServices.Administration.ApprovedStates]::LatestRevisionApproved
 $UpdateScope.UpdateTypes = [Microsoft.UpdateServices.Administration.UpdateType]::Software + [Microsoft.UpdateServices.Administration.UpdateType]::SoftwareApplication
 $UpdateScope.IncludedInstallationStates = [Microsoft.UpdateServices.Administration.UpdateInstallationStates]::NotInstalled + [Microsoft.UpdateServices.Administration.UpdateInstallationStates]::Downloaded + [Microsoft.UpdateServices.Administration.UpdateInstallationStates]::Installed + [Microsoft.UpdateServices.Administration.UpdateInstallationStates]::InstalledPendingReboot + [Microsoft.UpdateServices.Administration.UpdateInstallationStates]::Failed
 $UpdateScope.FromCreationDate = $fromDate
 $updateScope.ToCreationDate = $toDate

$WSUSServers = $AllWSUSServers #Array of resolvable names of WSUS Servers
$WSUSCount = $WSUSServers.count
$CurWSUSServer = 0
$UpdateReport = @()
Foreach ($WSUSServer in $WSUSServers){
 $CurWSUSServer++
 Write-Host "Connecting to Update server $WSUSServer ($CurWSUSServer of $WSUSCount) ... " -NoNewline -foregroundColor Green
 Try {
  $wsus = Get-WsusServer -Name $WSUSServer -PortNumber 8530
 }
 Catch{ 
  Try {  
   $wsus = Get-WsusServer -Name $WSUSServer -PortNumber 80
  }
  Catch [System.InvalidOperationException] {
   $errors++
   if ($_.FullyQualifiedErrorId -like "*ServerIsInvalid*"){
    Write-host "Error" -ForegroundColor Red
    Write-Error "Server $WsusServer Not Found Skipping"
    continue;
   }
   Else {
    Write-Error "Server $wsusServer is not a WSUS Server"
    break;
   }
   Catch {
    $errors++
    Write-host "Error" -ForegroundColor Red
    Throw $_
   }
  }
 } 
 Write-Host "Geting List of Updates" -foregroundColor Yellow
 $Updates = $wsus.GetUpdates($UpdateScope) 
 $ServerUpdates = $updates.Count
 $CurrUpdate = 0
 
 $CTGroups = $wsus.GetComputerTargetGroups()
 $HTCTGroup = @{}
 foreach ($CTGroup in $CTGroups){
  $HTCTGroup.Add($CTGroup.id,$CTGroup)
 }
 Foreach ($Update in $Updates){
  $rebootRequired = If($update.InstallationBehavior.RebootBehavior -like "CanRequest*"){$true}Else{$False}
  $CurrUpdate++
  $Approvals = $update.GetUpdateApprovals()
  Write-Host "Working on $WSUSServer ($CurWSUSServer of $WSUSCount) : Update $CurrUpdate of $ServerUpdates : $($Approvals.count) Approvals" -foregroundColor Gray
  $kbarts = ""
  $Update.KnowledgebaseArticles | foreach {if($Kbarts -eq ""){$kbarts = $_}Else{$Kbarts += ",$_"}}
  $Catagories = ""
  $Update.GetUpdateCategories() | foreach {if($Catagories -eq ""){$Catagories = $_.Title.trim()}Else{$Catagories += ",$($_.Title.trim())"}}
  $Classifications = $Update.GetUpdateClassification().title 
  foreach ($Approval in $Approvals){
   $TargetGroup = $HTCTGroup[$Approval.ComputerTargetGroupId]
   $GroupSum = $Update.GetSummaryForComputerTargetGroup($TargetGroup,$true)
   $Targets = $TargetGroup.GetComputerTargets($true)
   $InstNAPc = IF($targets.count -eq 0){0}Else{[math]::Round(($GroupSum.InstalledCount + $GroupSum.NotApplicableCount)/($targets.count),4)}
   $UnKPC = IF($targets.count -eq 0){0}Else{[math]::Round(($GroupSum.UnknownCount)/($targets.Count),4)}
   $NeedPC = IF($targets.count -eq 0){0}Else{[math]::Round(($GroupSum.DownloadedCount + $GroupSum.FailedCount + $GroupSum.NotInstalledCount)/($targets.Count),4)}
   $App2Sum = (New-TimeSpan -Start $Approval.CreationDate -End $GroupSum.LastUpdated).TotalDays
   $Rel2Sum = (New-TimeSpan -Start $Update.CreationDate -End $GroupSum.LastUpdated).TotalDays
   if ($GroupSum.LastUpdated -Ne 0){
    $ApprovalReport = New-Object psobject
     $ApprovalReport | Add-member -MemberType NoteProperty -Name UpdateID -Value $Update.Id.Updateid
     $ApprovalReport | Add-Member -MemberType NoteProperty -Name UpdateTitle -Value $Update.Title
     $ApprovalReport | Add-Member -MemberType NoteProperty -Name UpdateCategory -Value $Catagories
     $ApprovalReport | Add-Member -MemberType NoteProperty -Name UpdateClassification -Value $Classifications
     $ApprovalReport | Add-Member -MemberType NoteProperty -Name MSRCSeverity -Value $Update.MsrcSeverity
     $ApprovalReport | Add-Member -MemberType NoteProperty -Name KBArticle -Value $kbarts
     $ApprovalReport | Add-Member -MemberType NoteProperty -Name RevisionID -Value $Update.Id.RevisionNumber
     $ApprovalReport | Add-Member -MemberType NoteProperty -Name isLatestRevision -Value $update.IsLatestRevision
     $ApprovalReport | Add-Member -MemberType NoteProperty -Name IsSuperseded -Value $update.IsSuperseded
     $ApprovalReport | Add-Member -MemberType NoteProperty -Name RebootPossible -Value $rebootRequired
     $ApprovalReport | Add-Member -MemberType NoteProperty -Name UpdateServer -Value $Update.UpdateServer.Name
     $ApprovalReport | Add-Member -MemberType NoteProperty -Name TargetGroup -Value $TargetGroup.name
     $ApprovalReport | Add-Member -MemberType NoteProperty -Name ReleaseTime -value $Update.CreationDate
     $ApprovalReport | Add-Member -MemberType NoteProperty -Name AvailableTime -Value $Update.ArrivalDate
     $ApprovalReport | Add-Member -MemberType NoteProperty -Name ApprovalID -Value $Approval.id
     $ApprovalReport | Add-Member -MemberType NoteProperty -Name ApprovedTime -Value $Approval.CreationDate
     $ApprovalReport | Add-Member -MemberType NoteProperty -Name ApprovedBy -value $Approval.AdministratorName
     $ApprovalReport | Add-Member -MemberType NoteProperty -Name Deadline -Value $Approval.deadline
     $ApprovalReport | Add-Member -MemberType NoteProperty -Name Targets -Value $Targets.count
     $ApprovalReport | Add-Member -MemberType NoteProperty -Name Downloaded -Value $GroupSum.DownloadedCount
     $ApprovalReport | Add-Member -MemberType NoteProperty -Name PendingReboot -Value $GroupSum.InstalledPendingRebootCount
     $ApprovalReport | Add-Member -MemberType NoteProperty -Name Installed -Value $GroupSum.InstalledCount
     $ApprovalReport | Add-Member -MemberType NoteProperty -Name Failed -Value $GroupSum.FailedCount
     $ApprovalReport | Add-Member -MemberType NoteProperty -Name Unknown -Value $GroupSum.UnknownCount
     $ApprovalReport | Add-Member -MemberType NoteProperty -Name NotApplicable -Value $GroupSum.NotApplicableCount
     $ApprovalReport | Add-Member -MemberType NoteProperty -Name SummaryUpdated -Value $GroupSum.LastUpdated
     $ApprovalReport | Add-Member -MemberType NoteProperty -Name App2Sum -Value $App2Sum
     $ApprovalReport | Add-Member -MemberType NoteProperty -Name Rel2Sum -Value $Rel2Sum
     $ApprovalReport | Add-Member -MemberType NoteProperty -Name NeededPC -Value $NeedPC
     $ApprovalReport | Add-Member -MemberType NoteProperty -Name UnKPC -Value $UnKPC
     $ApprovalReport | Add-Member -MemberType NoteProperty -Name InstNAPC -Value $InstNAPc
    $UpdateReport += $ApprovalReport
   }
  }
 }
}
$UpdateReport | export-csv -NoTypeInformation -Path "\\PathTo\Reports\wsus-reports\ApprovalReport_$timestamp.csv" -Force

$sw.stop()
Write-host "Total Approvals checked $($updateReport.count)" -ForegroundColor Yellow -BackgroundColor Black -NoNewline
$color = if ($errors -ne 0) {"Red"}Else{"Yellow"}
Write-Host " with $errors errors" -ForegroundColor $color -BackgroundColor Black
Write-Host "Report AT: \\stft13334\wsus-reports\ApprovalReport_$timestamp.csv" -ForegroundColor darkYellow -BackgroundColor Black
write-host $sw.elapsed.tostring("G") -ForegroundColor Yellow -BackgroundColor Black
