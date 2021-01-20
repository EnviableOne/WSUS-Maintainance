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
    Version 2.0   - https://github.com/EnviableOne/WSUS-Maintainance
#>

[void][reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration") 

# For all WSUS servers in Environment
# cleanup in reverse tier order (i.e. downstream first)
$WsusServers = ("wsus-pcs","wsus-com") #tier 1 (have downstream servers)
#$WSUSServers = ("wsus-servers","wsus-pcs2","wsus-3","wsus-5","wsus-6","wsus-8","wsus-9","wsus-12","wsus-13","wsus-14") #Tier 2 (have no downstream servers)

# In case need to check for some individual server or few particular servers
#$WSUSServers = ("wsus-6","wsus-13")

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
[bool]$obsoleteComputers = $True     #Delete
[bool]$unneededContentFiles = $False #Delete

Write-host "Stopping Syncronisation" -ForegroundColor Green
foreach ($WSUSServer in $WSUSServers) {
 Try { 
        Try {
            $WSUS = Get-WSUSServer -name $WSUSServer -port 8530
        }
        Catch {
            $WSUS = Get-WSUSServer -name $WSUSServer -port 80
        }
        Write-Host ("Connected to {0}. Stopping Syncronisation ..." -f $WSUS.Name) -foregroundcolor DarkGray -nonewline
        $sub = $wsus.GetSubscription()
        $sub.StopSynchronization() 
        $sub.SynchronizeAutomatically = $false
        $sub.Save()
        #Set-WSUSServerSync -updateServer $wsus -replica:$false -USS ""
        Write-Host "done" -foregroundcolor Green
 }
 Catch [Exception] {
        if($wsus.name -ne $WSUSServer){
         Write-Host "Failed to connect to $WsusServer" -ForegroundColor white -BackgroundColor Red
        }
        Else{
         Write-Host "error." -ForegroundColor white -BackgroundColor Red
        }
        write-host $_.Exception.GetType().FullName -ForegroundColor white -BackgroundColor Red
	    write-host $_.Exception.Message -ForegroundColor white -BackgroundColor Red
        continue;
 }
 
}

#cleanup hosts
ForEach ($WSUSServer in $WSUSServers) {
    $WorkingonWSUS = $WorkingonWSUS + 1
    #Read-Host "Put $WSUSServer into maintenance mode. Once done,press Enter to continue ..." | Out-Null

    write-host "Working on $WSUSServer ($WorkingonWSUS of $AllWSUSCount) ..."	-foregroundcolor Green
    Try { 
        Try {
            $WSUS = Get-WSUSServer -name $WSUSServer -port 8530
        }
        Catch {
            $WSUS = Get-WSUSServer -name $WSUSServer -port 80
        }
	    write-host "Connected with $WSUSServer ($WorkingonWSUS of $AllWSUSCount) and proceeding for cleanup ..."	-foregroundcolor Yellow
	    ##CleanupScope(bool supersededUpdates,bool expiredUpdates,bool obsoleteUpdates,bool compressUpdates,bool obsoleteComputers,bool unneededContentFiles)
	    $cleanupScope = new-object Microsoft.UpdateServices.Administration.CleanupScope($supersededUpdates,$expiredUpdates,$obsoleteUpdates,$compressUpdates,$obsoleteComputers,$unneededContentFiles); 
        write-host "Starting Cleanup on $WSUSServer ($WorkingonWSUS of $AllWSUSCount) ..."
	    $cleanupManager = $WSUS.GetCleanupManager();
	    $cleanupManager.PerformCleanup($cleanupScope); 
    	write-host "Cleaning done for $WSUSServer ($WorkingonWSUS of $AllWSUSCount)" -ForegroundColor Darkgray
    }
    Catch [Exception] {
        write-host $_.Exception.GetType().FullName -ForegroundColor white -BackgroundColor Red
	    write-host $_.Exception.Message -ForegroundColor white -BackgroundColor Red
	    continue;
    }
}

Write-host "Restart syncronisation" -foregroundcolor Green
foreach ($wsusserver in $WSUSServers) {
 Try { 
        Try {
            $WSUS = Get-WSUSServer -name $WSUSServer -port 8530
        }
        Catch {
            $WSUS = Get-WSUSServer -name $WSUSServer -port 80
        }
        Write-Host ("Connected to {0}. Starting Syncronisation ..." -f $WSUS.Name) -foregroundcolor DarkGray -nonewline
        $sub = $wsus.GetSubscription()
        $sub.SynchronizeAutomatically = $True
        $sub.Save()
        write-host "done" -ForegroundColor Green
        #Set-WSUSServerSync -updateServer $wsus -replica:$false -USS ""
 }
 Catch [Exception] {
        if($wsus.name -ne $WSUSServer){
         Write-Host "Failed to connect to $WsusServer" -ForegroundColor white -BackgroundColor Red
        }
        Else{
         Write-Host "error." -foregroundcolor white -BackgroundColor Red
        }
        write-host $_.Exception.GetType().FullName -ForegroundColor white -BackgroundColor Red
	    write-host $_.Exception.Message -ForegroundColor white -BackgroundColor Red
	    continue;
    }
}

Stop-Transcript
