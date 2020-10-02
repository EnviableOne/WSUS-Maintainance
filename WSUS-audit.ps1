<#
.SYNOPSIS
    This script performs an audit on WSUS servers in the Local Domain
 
.DESCRIPTION
    This Script uses the System.Microsoft.UpdateServices.Administration
    to query all specified WSUS Servers for details of the connected
    Machines and the status of all updates they have been sent.
    It then generates a report (per server) with numbers of updates 
    for each machine in by state, with a list of the KBs required and
    the date they were downloaded by the server.
    It then generates a report from each server on the patch progress 
    of the current month's (between patch Tuesdays) updates and lists
    the number of machines with each state with respect to that update
     
.INPUTS
    $WSUSServers List of WSUS Server names (must be resovable)
    $ReportPath  where to create the reports
 
.OUTPUTS
    comma seperated variable file reports for each server:
       
       Currentmonthupdates_<SERVERNAME>_<RUNTIME>.csv
       Summary by update of this months updates

       AllServersStatus_<SERVERNAME>_<RUNTIME>.csv 
       summary by target of update states with list of required
 
.NOTES
    Author        Version   Date
    Peter Marquis 2.1       27 August 2020
    Peter Marquis 2.0       13 March 2019
    Nitish Kumar  1.2       21 May 2017
    
.LICENCE
   Copyright {2020} {Enviable Network Support and Solutions Ltd.}

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.

.LINK
    Original Code - https://nitishkumar.net/2017/03/08/wsus-and-powershell-audit-compliance-report-and-automatic-cleanup/
    Version 2.1   - https://github.com/EnviableOne/WSUS-Maintainance
#>
function Get-PatchTue 
{ 
<#  
  .SYNOPSIS   
    Get the Patch Tuesday of a month 
  .PARAMETER month 
   The month to check
  .PARAMETER year 
   The year to check
  .EXAMPLE  
   Get-PatchTue -month 6 -year 2015
  .EXAMPLE  
   Get-PatchTue June 2015
#> 
 
param( 
[string]$month = (get-date).month, 
[string]$year = (get-date).year
) 

$firstdayofmonth = [datetime] ([string]$month + "/1/" + [string]$year)
(0..14 | % {$firstdayofmonth.adddays($_) } | ? {[int]$_.dayofweek -eq 2})[1]
 
}
[void][reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration")
[GC]::Collect()
$Clock = [System.Diagnostics.Stopwatch]::StartNew();
$DomainName = "."+ $env:USERDNSDOMAIN
$dateText = (Get-Date).ToString('MM-dd-yyyy_hh-mm')
$ReportPath = "C:\WSUS-Reports"                         #Path to store reports
$Current=$true                                          #True for since Patch-Tue, false for last full patch month

# For WSUS servers catering servers
$WSUSServers = ("wsus-pcs","wsus01-com","wsus-servers","wsus-pcs2")
#$WSUSServers= ("wsus-pcs")

$ServerCount = ($WSUSServers | measure).count
$CurServer = 0
$UpdateDetails = @{}

$thisDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$logFile = "WSUSAuditReports_$dateText.txt"
If(!(Test-Path $ReportPath)){
  New-item -path $ReportPath -ItemType Directory -Force 
}
Start-Transcript -Path $thisDir\$logFile


ForEach ($WSUSServer in $WSUSServers) {
    $CurServer = $CurServer+1		
    write-host "Working on $WSUSServer ($CurServer of $ServerCount) ..."	-foregroundcolor Green
	Try {
        
		Try {
				$CurWSUSServer = [Microsoft.UpdateServices.Administration.AdminProxy]::getUpdateServer($WSUSServer,$false,8530)
		}
		Catch {
				$CurWSUSServer = [Microsoft.UpdateServices.Administration.AdminProxy]::getUpdateServer($WSUSServer,$false,80)
		}
		write-host "Connected and Fetching data for all computers connecting to it..."	-NoNewline
		
        $ComputerScope = New-Object Microsoft.UpdateServices.Administration.ComputerTargetScope
        $ComputerScope.IncludeDownstreamComputerTargets = $true
		$UpdateScope = New-Object Microsoft.UpdateServices.Administration.UpdateScope
		$UpdateScope.ApprovedStates = [Microsoft.UpdateServices.Administration.ApprovedStates]::LatestRevisionApproved
		$updatescope.IncludedInstallationStates = [Microsoft.UpdateServices.Administration.UpdateInstallationStates]::All
        #$UpdateScope.TextIncludes = "monthly" -and "Windows 7"
		
		$GroupTargets = $CurWSUSServer.GetComputerTargets($computerScope)
        $Summaries = $CurWSUSServer.GetSummariesPerComputerTarget($updatescope, $computerscope)
        $CompCount = ($Summaries | measure).count
        $CurComp = 0
        Write-host "done."	-ForegroundColor Gray
        Write-Host "Generate $WSUSServer Reference Table ..." -NoNewline -ForegroundColor DarkGray
        # Create empty objects to contain collected data.
        $SummaryStatus = @()
        $TargetHashes = @{}
        foreach ($_ in $GroupTargets) {
            $TargetHashes.add($_.id,$_)
        }
		Write-Host "done." -ForegroundColor Gray
		Foreach ($Summary in $Summaries) 
		{
			Try {
                $CurComp = $CurComp+1
                write-host "Parsing data for Target $CurComp of $CompCount on $WSUSServer ($CurServer of $ServerCount)..."	-foregroundcolor Yellow -NoNewline
                #pull target from hashtable
                $Target = $TargetHashes[$Summary.ComputerTargetId]
                $ComputerTargetToUpdate = $Target
                #set update scope
                $neededScope = New-Object Microsoft.UpdateServices.Administration.UpdateScope
                $neededScope.IncludedInstallationStates = [Microsoft.UpdateServices.Administration.UpdateInstallationStates]::Downloaded,[Microsoft.UpdateServices.Administration.UpdateInstallationStates]::Failed,[Microsoft.UpdateServices.Administration.UpdateInstallationStates]::NotInstalled
                $neededScope.ApprovedStates = [Microsoft.UpdateServices.Administration.ApprovedStates]::LatestRevisionApproved 
				$NeededUpdate = $ComputerTargetToUpdate.GetUpdateInstallationInfoPerUpdate($neededScope)  | where {($_.UpdateApprovalAction -eq "install") -and (($_.UpdateInstallationState -eq "Downloaded") -or ($_.UpdateInstallationState -eq "Notinstalled") -or ($_.UpdateInstallationState -eq "Failed"))	}
				$NeededUpdateReport = @()
				$NeededUpdateDateReport = @()
				
                if ($NeededUpdate -ne $null) {
                    write-Host "$($NeededUpdate.count) Updates Required ..." -nonewline -foregroundcolor DarkGray
				    foreach ($Update in $NeededUpdate) {
                        if ($UpdateDetails.ContainsKey([Guid]$Update.updateid)){
					     $NeededUpdateReport += $UpdateDetails[[Guid]$Update.updateid].KnowledgebaseArticles
						 $NeededUpdateDateReport += $UpdateDetails[[Guid]$Update.updateid].ArrivalDate.ToString("dd/MM/yyyy ")
                        }
                        else{
                         $NeedUpd = $CurWSUSServer.GetUpdate([Guid]$Update.updateid) 						
					     $NeededUpdateReport += $NeedUpd.KnowledgebaseArticles
						 $NeededUpdateDateReport += $NeedUpd.ArrivalDate.ToString("dd/MM/yyyy ")
                         $updatedetails.add([Guid]$Update.updateid,$needUpd)
                        }
					}
				}
                #Generate report Record
                $TargetData = New-Object -TypeName PSObject
		    	if ($Target.ParentServerId -eq '00000000-0000-0000-0000-000000000000'){$Parent = $WSUSServer}else{$Parent = ($target.GetParentServer().FullDomainName -replace $DomainName, "")}
                $TargetData | add-member -Type NoteProperty -Name WSUSServer -Value $Parent
		    	$TargetData | add-member -type Noteproperty -Name Device -Value (($Target | select -ExpandProperty FullDomainName) -replace $DomainName, "")
			    $TargetData | add-member -type Noteproperty -Name NotInstalledCount -Value $Summary.NotInstalledCount
				$TargetData | add-member -type Noteproperty -Name NotApplicable -Value $Summary.NotApplicableCount
				$TargetData | add-member -type Noteproperty -Name DownloadedCount -Value $Summary.DownloadedCount
				$TargetData | add-member -type Noteproperty -Name InstalledCount -Value $Summary.InstalledCount
				$TargetData | add-member -type Noteproperty -Name InstalledPendingRebootCount -Value $Summary.InstalledPendingRebootCount
				$TargetData | add-member -type Noteproperty -Name FailedCount -Value $Summary.FailedCount
				$TargetData | add-member -type Noteproperty -Name NeededCount -Value ($NeededUpdate | measure).count
				$TargetData | add-member -type Noteproperty -Name Needed -Value $NeededUpdateReport
				$TargetData | add-member -type Noteproperty -Name LastSyncTime -Value $Target.LastSyncTime
				$TargetData | add-member -type Noteproperty -Name IPAddress -Value $Target.IPAddress
				$TargetData | add-member -type Noteproperty -Name OS -Value $Target.OSDescription
				$TargetData | add-member -type Noteproperty -Name NeededDate -Value $NeededUpdateDateReport
                $up2Date = IF(($NeededUpdate | measure).count -eq 0){1}Else{0}
                $TargetData | add-member -type NoteProperty -Name Up2Date -Value $up2Date
				$SummaryStatus += $TargetData 
                Write-Host "done." -ForegroundColor Gray
            }
            Catch [Microsoft.UpdateServices.Administration.WsusObjectNotFoundException]{
                $CurHost = $TargetHashes[$Summary.ComputerTargetId] | select -expandProperty FullDomainName
                $CurHost = $CurHost.substring(0,$CurHost.indexof("."))
                Write-host "Target not found - $CurHost checking for issues" -foregroundcolor Magenta
                #Primary AD Lookup ($env:userdomain)
                Try { 
                    Get-ADComputer -identity $Summary.computertargetid | out-null
                    Write-Host "Computer Exists IN Local AD - Further investigation Required - Try WSUS Cleanup" -Foregroundcolor Red
                }
                Catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
                    #Secondary AD Lookup (defined - Must have 2 way trust)
                    Try { 
                        Get-ADComputer -identity $Summary.computertargetid | out-null
                        Write-Host "Computer Exists IN Local AD - Further investigation Required - Try WSUS Cleanup" -Foregroundcolor Red
                    }
                    Catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
                        Write-Host " Summary for $($Summary.computertargetid) has no WSUS Target or AD Computer record, Deleting from WSUS" -Foregroundcolor Yellow
                        $ComputerTargetToUpdate.Delete()
                    }
                }
		    }
        }
        Write-Host "Writing Summary for $WSUSServer to report ..." -nonewline -foregroundcolor DarkGray
		$SummaryStatus | select-object WSUSServer,Device,NeededCount,LastSyncTime,InstalledPendingRebootCount,NotInstalledCount,DownloadedCount,InstalledCount,FailedCount,@{Name="KB Numbers"; Expression = {$_.Needed}},@{Name="Arrival Date"; Expression = {$_.NeededDate}},NotApplicable,IPAddress,OS,Up2Date|export-csv -notype ("$ReportPath\PerDeviceStatus_$WSUSServer" + "_$dateText.csv")
		Write-Host "done." -ForegroundColor Gray
		
        #Create lookup report for Needed Updates
        Write-Host "Writing Needed Updates for $WSUSServer to report ..." -nonewline -foregroundcolor DarkGray
        $updatedetails.Values | select ArrivalDate,Title,UpdateType,@{L="Classification";E={$_.UpdateClassificationTitle}},MsrcSeverity,@{L="Company";E={$_.CompanyTitles}},@{L="ProductFamily";E={$_.ProductFamilyTitles}},@{L="ProductTitle";E={$_.ProductTitles}},Description,@{L="KBArticle";E={$_.KnowledgebaseArticles}},@{L="SecurityBulletin";E={$_.SecurityBulletins}},IsLatestRevision,IsApproved,@{L="AdditionalInformationUrl";E={$_.AdditionalInformationUrls}} | Export-Csv -notype ("$ReportPath\Updates_Required_$WSUSServer" + "_$dateText.csv")
        Write-Host "done." -ForegroundColor Gray

		# Find The most recent 2 patch tuesdays
        $ToYear = (Get-date).Year
        if ((Get-Date) -lt (Get-PatchTue)){
         Switch ((get-date).Month){
          1 {
           $ToMonth = 12
           $ToYear--
           $FromMonth=11
           $FromYear = $ToYear--
          }
          2 {
           $ToMonth = 1
           $FromMonth = 12
           $FromYear = $ToYear--
          }
          Default{
           $ToMonth = (get-date).Month -1
           $FromMonth = $ToMonth--
           $FromYear = $ToYear
          }
         }
        }
        Else {
         If ((get-date).Month -eq 1){ 
          $ToMonth = (get-date).Month
          $FromMonth = 12
          $FromYear = $ToYear--
         }
         Else {
          $ToMonth = (get-date).Month
          $FromMonth = $ToMonth--
          $FromYear = $ToYear
         }
        }
        
        #Set Time Constraints for Update Report        
        If ($Current){
		 $updatescope.FromArrivalDate = Get-PatchTue -month $ToMonth -year $ToYear
         $text = "Since Last Patch Tuesday"
        }
        Else {
         $updatescope.FromArrivalDate = Get-PatchTue -month $FromMonth -year $FromYear
		 $updatescope.ToArrivalDate = Get-PatchTue -month $ToMonth -year $ToYear
         $text = "for the month to last Patch Tuesday"
        }
                
        #collect Summaries per patch from the update server
        $PerUpdateFile = "$ReportPath\Currentmonthupdates_"+$WSUSServer+"_$dateText.csv"
        write-host "Connected with $WSUSServer and finding patches for $text .." -NoNewline	
		$CurWSUSServer.GetSummariesPerUpdate($updatescope,$computerscope) | select-object @{L='UpdateTitle';E={(If($UpdateDetails.containsKey([guid]$_.UpdateID)){$UpdateDetails[[Guid]$_.UpdateID]}Else{$CurWSUSServer.GetUpdate([guid]$_.UpdateId)}).Title}},@{L='Arrival Date';E={(If($UpdateDetails.containsKey([guid]$_.UpdateID)){$UpdateDetails[[Guid]$_.UpdateID]}Else{$CurWSUSServer.GetUpdate([guid]$_.UpdateId)}).ArrivalDate}},@{L='KB Article';E={(If($UpdateDetails.containsKey([guid]$_.UpdateID)){$UpdateDetails[[Guid]$_.UpdateID]}Else{$CurWSUSServer.GetUpdate([guid]$_.UpdateId)}).KnowledgebaseArticles}},@{L='Needed';E={($_.DownloadedCount+$_.NotInstalledCount)}},DownloadedCount,NotApplicableCount,NotInstalledCount,InstalledCount,FailedCount | Export-csv -Notype $PerUpdateFile
		write-host "done." -ForegroundColor Green
    }
	Catch [Exception] {
		write-host $_.Exception.GetType().FullName -foregroundcolor Red
		write-host $_.Exception.Message -foregroundcolor Red
        continue;
	}
}
$Clock.Stop()
#output run summary
Write-Host "Total Servers checked : " -NoNewline -ForegroundColor Green -BackgroundColor Black
Write-Host $CurServer -ForegroundColor Yellow -backgroundcolor Black
Write-Host "Different updates needed : " -NoNewline -ForegroundColor Green -BackgroundColor Black
Write-Host $UpdateDetails.count	-ForegroundColor Yellow	-BackgroundColor Black
Write-Host "Time elapsed : " -NoNewline -ForegroundColor Green -BackgroundColor Black
Write-Host $Clock.elapsed.tostring("G") -ForegroundColor Yellow -BackgroundColor Black
Stop-Transcript
notepad $thisDir\$logFile
