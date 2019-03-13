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
    Peter Marquis 2.0       13 March 2019
    Nitish Kumar  1.2       21 May 2017
    
.LICENCE
   Copyright {2019} {Enviable Network Support and Solutions Ltd.}

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
    Version 2.0   - https://github.com/EnviableOne/WSUS-Maintainance
#>

[void][reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration")

$firstdayofmonth = [datetime] ([string](get-date).AddMonths(-1).month + "/1/" + [string](get-date).year)
$DomainName = "."+ $env:USERDNSDOMAIN
$dateText = (Get-Date).ToString('MM-dd-yyyy_hh-mm-ss')
$ReportPath = "C:\WSUS-Reports"

# Create empty arrays to contain collected data.
$UpdateStatus = @()
$SummaryStatus = @()		

# For WSUS servers catering servers
$WSUSServers = ("wsus-pcs","wsus01-com","wsus-servers","EMIS-SPOKE-3","EMIS-SPOKE-4","EMIS-SPOKE-5","EMIS-SPOKE-6","EMIS-SPOKE-7","EMIS-SPOKE-8","EMIS-SPOKE-9")

$ServerCount = ($WSUSServers | measure).count
$CurServer = 0

$thisDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$logFile = "WSUSAuditReports_$dateText.txt"
Start-Transcript -Path $thisDir\$logFile


ForEach ($WSUSServer in $WSUSServers) {		
    write-host "Working on $WSUSServer ..."	-foregroundcolor Green
    $CurServer = $CurServer+1
	Try {
        
		Try {
				$CurWSUSServer = [Microsoft.UpdateServices.Administration.AdminProxy]::getUpdateServer($WSUSServer,$false,8530)
		}
		Catch {
				$CurWSUSServer = [Microsoft.UpdateServices.Administration.AdminProxy]::getUpdateServer($WSUSServer,$false,80)
		}
		
		$ComputerScope = New-Object Microsoft.UpdateServices.Administration.ComputerTargetScope
		$UpdateScope = New-Object Microsoft.UpdateServices.Administration.UpdateScope
		$UpdateScope.ApprovedStates = [Microsoft.UpdateServices.Administration.ApprovedStates]::LatestRevisionApproved
		$updatescope.IncludedInstallationStates = [Microsoft.UpdateServices.Administration.UpdateInstallationStates]::All

		$AllCompGroup = $CurWSUSServer.GetComputerTargetGroups() | Where {$_.Name -eq 'All Computers'}
		$GroupTargets = $CurWSUSServer.getComputerTargetGroup($AllCompGroup.Id).GetComputerTargets()

        write-host "Connected and Fetching the data from $WSUSServer for all computers connecting to it..."	
        $Summaries = $CurWSUSServer.GetSummariesPerComputerTarget($updatescope, $computerscope)
        $CompCount = ($Summaries | measure).count
        $CurComp = 0

		write-host "Data recieved from $WSUSServer for all computers connecting to it..."	
		Foreach ($Summary in $Summaries) 
		{
			Try {
                $CurComp = $CurComp+1
                write-host "Getting data from number $CurComp of $CompCount computers on $WSUSServer ($CurrServer of $ServerCount)..."	-foregroundcolor Yellow
                Foreach ($Target in $GroupTargets) {
				    If ($Summary.computertargetid -match $Target.id) {
					    $ComputerTargetToUpdate = $CurWSUSServer.GetComputerTargetByName($Target.FullDomainName)                    
					    $NeededUpdate = $ComputerTargetToUpdate.GetUpdateInstallationInfoPerUpdate() | where {($_.UpdateApprovalAction -eq "install") -and (($_.UpdateInstallationState -eq "Downloaded") -or ($_.UpdateInstallationState -eq "Notinstalled") -or ($_.UpdateInstallationState -eq "Failed"))	}
					    $FailedUpdateReport = @()
					    $NeededUpdateReport = @()
					    $NeededUpdateDateReport = @()
					    if ($NeededUpdate -ne $null) {
				    	    foreach ($Update in $NeededUpdate) {						
							    $NeededUpdateReport += ($CurWSUSServer.GetUpdate([Guid]$Update.updateid)).KnowledgebaseArticles
							    $NeededUpdateDateReport += ($CurWSUSServer.GetUpdate([Guid]$Update.updateid)).ArrivalDate.ToString("dd/MM/yyyy ")
						    }
					    }
    					$Target | select -ExpandProperty FullDomainName                    
	    				$TargetData = New-Object -TypeName PSObject
		    			$TargetData | add-member -type Noteproperty -Name Server -Value (($Target | select -ExpandProperty FullDomainName) -replace $DomainName, "")
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
					    $SummaryStatus += $TargetData
                        }
				    }
			    }
            Catch [Microsoft.UpdateServices.Administration.WsusObjectNotFoundException]{
                Write-host "Target not found - checking for issues" -foregroundcolor Magenta
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
                continue;
            }
		}
		$SummaryStatus | select-object server,NeededCount,LastSyncTime,InstalledPendingRebootCount,NotInstalledCount,DownloadedCount,InstalledCount,FailedCount,@{Name="KB Numbers"; Expression = {$_.Needed}},@{Name="Arrival Date"; Expression = {$_.NeededDate}},NotApplicable,IPAddress,OS|export-csv -notype ("$ReportPath\AllServersStatus_$WSUSServer" + "_$dateText.csv")
		
		write-host "Connected with $WSUSServer and finding patches for last month schedule .." -NoNewline	
		# Find patches from 1st day of (M-2) month to 2nd Monday of (M-1) month 
		$updatescope.FromArrivalDate = [datetime](get-date).Addmonths(-2).AddDays(-((Get-date).day-1))

		$updatescope.ToArrivalDate = [datetime](0..31 | % {$firstdayofmonth.adddays($_) } | ? {$_.dayofweek -like "Mon*"})[1]
		#[datetime](0..31 | % {$firstdayofmonth.adddays($_) } | ? {$_.dayofweek -like "Mon*"})[1]

		$PerUpdateFile = "$ReportPath\Currentmonthupdates_"+$WSUSServer+"_$dateText.csv"
		$CurWSUSServer.GetSummariesPerUpdate($updatescope,$computerscope) |select-object @{L='UpdateTitle';E={($CurWSUSServer.GetUpdate([guid]$_.UpdateId)).Title}},@{L='Arrival Date';E={($CurWSUSServer.GetUpdate([guid]$_.UpdateId)).ArrivalDate}},@{L='KB Article';E={($CurWSUSServer.GetUpdate([guid]$_.UpdateId)).KnowledgebaseArticles}},@{L='Needed';E={($_.DownloadedCount+$_.NotInstalledCount)}},DownloadedCount,NotApplicableCount,NotInstalledCount,InstalledCount,FailedCount | Export-csv -Notype $PerUpdateFile
		write-host "done."
    }
	Catch [Exception] {
		write-host $_.Exception.GetType().FullName -foregroundcolor Red
		write-host $_.Exception.Message -foregroundcolor Red
        continue;
	}
}
		
Stop-Transcript
notepad $thisDir\$logFile