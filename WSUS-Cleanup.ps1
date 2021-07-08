<#
.SYNOPSIS
    This script performs an Cleanup on WSUS servers in the Local Domain
 
.DESCRIPTION
    This Script uses the System.Microsoft.UpdateServices.Administration
    to perform the WSUS Cleanup Routine on all WSUS servers listed with 
    any options enabled and outputs a transcript with the results per 
    listed Server
     
.INPUTS
    $WSUSServers List of WSUS Server names (must be resovable)
     
.OUTPUTS
    a text file containing the progress and results of each servers
    cleanup 
 
.NOTES
    Author        Version   Date
    Peter Marquis 2.1       20 January 2021
    Peter Marquis 2.0       13 March 2019
    Nitish Kumar  1.2       21 May 2017
    
.LICENCE
   Copyright {2021} {Enviable Network Support and Solutions Ltd.}

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
    Version 2.0+   - https://github.com/EnviableOne/WSUS-Maintainance
#>

[void][reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration") 

# For all WSUS servers in Environment
# cleanup in reverse tier order (i.e. downstream first)
#$WsusServers = ("wsus-pcs","wsus-com") #tier 1 (have downstream servers)
$WSUSServers = ("wsus-servers","wsus-pcs2","WSUS-3","WSUS-5","WSUS-8","WSUS-9","WSUS-12","WSUS-13","WSUS-14","WSUS-15","WSUS-16") #Tier 2 (have no downstream Servers)

# In case need to check for some individual server or few particular servers
#$WSUSServers = ("wsus-pcs3")

$AllWSUSCount = ($WSUSServers | measure).count
$WorkingonWSUS = 0
import-module UpdateServices

$thisDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$logFile = "WSUSCleanupResults_$((Get-Date).ToString('MM-dd-yyyy_hh-mm-ss')).txt"
Start-Transcript -Path $thisDir\$logFile

#Select Cleanup Options
[bool]$supersededUpdates = $True     #Decline
[bool]$expiredUpdates = $True        #Decline
[bool]$obsoleteUpdates = $True       #Delete
[bool]$compressUpdates = $false      #Compress
[bool]$obsoleteComputers = $false     #Delete
[bool]$unneededContentFiles = $True  #Delete

#cleanup hosts
ForEach ($WSUSServer in $WSUSServers) {
    $WorkingonWSUS++
    #Read-Host "Put $WSUSServer into maintenance mode. Once done,press Enter to continue ..." | Out-Null

    write-host "Working on $WSUSServer ($WorkingonWSUS of $AllWSUSCount) ..."	-foregroundcolor Green
    Try { 
        Try {
            $WSUS = Get-WSUSServer -name $WSUSServer -port 8530
        }
        Catch {
            $WSUS = Get-WSUSServer -name $WSUSServer -port 80
        }
	    write-host "Connected with $WSUSServer ($WorkingonWSUS of $AllWSUSCount) and stopping sync ..."	-foregroundcolor DarkYellow -NoNewline
        $sub = $wsus.GetSubscription()
        $sub.StopSynchronization() 
        $sub.SynchronizeAutomatically = $false
        $sub.Save()
	    Write-Host "done." -ForegroundColor DarkGray
	    $cleanupScope = new-object Microsoft.UpdateServices.Administration.CleanupScope($supersededUpdates,$expiredUpdates,$obsoleteUpdates,$compressUpdates,$obsoleteComputers,$unneededContentFiles); 
        write-host "Starting Cleanup on $WSUSServer ($WorkingonWSUS of $AllWSUSCount) ..." -foregroundcolor Green
	    $cleanupManager = $WSUS.GetCleanupManager();
	    $cleanupManager.PerformCleanup($cleanupScope); 
    	write-host "Cleaning done for $WSUSServer ($WorkingonWSUS of $AllWSUSCount)" -ForegroundColor Gray
    }
    Catch [Exception] {
        write-host $_.Exception.GetType().FullName -ForegroundColor white -BackgroundColor Red
	    write-host $_.Exception.Message -ForegroundColor white -BackgroundColor Red
	    continue;
    }
    finally{
     Write-Host "Restarting Sync..." -NoNewline -ForegroundColor DarkYellow
     if(!$sub){ $sub=$wsus.GetSubscription()}
     $sub.SynchronizeAutomatically = $True
     $sub.Save()
     Write-Host "done." -ForegroundColor DarkGray
    }
}

Stop-Transcript
