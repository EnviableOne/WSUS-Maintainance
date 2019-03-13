<#
.SYNOPSIS
    This script performs an Cleanup on WSUS servers in the Local Domain
 
.DESCRIPTION
    This Script uses the System.Microsoft.UpdateServices.Administration
    to perform the WSUS Cleanup Routine on all WSUS servers listed with 
    all options enabled and outputs a transcript with the results per 
    listed Server
     
.INPUTS
    $WSUSServers List of WSUS Server names (must be resovable)
     
.OUTPUTS
    a text file containing the progress and results of each servers
    cleanup 
 
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

# For all WSUS servers in Environment
$WSUSServers = ("wsus-pcs","wsus01-com","wsus-servers","EMIS-SPOKE-3","EMIS-SPOKE-4","EMIS-SPOKE-5","EMIS-SPOKE-6","EMIS-SPOKE-7","EMIS-SPOKE-8","EMIS-SPOKE-9")

# In case need to check for some individual server or few particular servers
#$WSUSServers = ("EMIS-SPOKE-7","EMIS-SPOKE-8","EMIS-SPOKE-9")

$AllWSUSCount = ($WSUSServers | measure).count
$WorkingonWSUS = 0

$thisDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$logFile = "WSUSCleanupResults_$((Get-Date).ToString('MM-dd-yyyy_hh-mm-ss')).txt"
Start-Transcript -Path $thisDir\$logFile

$Reply = "@"

ForEach ($WSUSServer in $WSUSServers) {
    $WorkingonWSUS = $WorkingonWSUS + 1
    $WSUSServer

	#Read-Host "Put $WSUSServer into maintenance mode. Once done,press Enter to continue ..." | Out-Null

    write-host "Working on $WSUSServer ($WorkingonWSUS of $AllWSUSCount) ..."	-foregroundcolor Green
    Try { 
        Try {
            $WSUS = [Microsoft.UpdateServices.Administration.AdminProxy]::getUpdateServer($WSUSServer,$false,8530)
        }
        Catch {
            $WSUS = [Microsoft.UpdateServices.Administration.AdminProxy]::getUpdateServer($WSUSServer,$false,80)
        }
	    write-host "Connected with $WSUSServer ($WorkingonWSUS of $AllWSUSCount)and proceeding for cleanup ..."	-foregroundcolor Yellow
	    
	    $cleanupScope = new-object Microsoft.UpdateServices.Administration.CleanupScope; 
    	$cleanupScope.CleanupObsoleteComputers = $true
    	$cleanupScope.DeclineSupersededUpdates = $true
    	$cleanupScope.DeclineExpiredUpdates = $true
	    $cleanupScope.CleanupObsoleteUpdates = $true
	    $cleanupScope.CleanupUnneededContentFiles = $true
	    $cleanupScope.CompressUpdates = $true 
        write-host "Starting Cleanup on $WSUSServer ($WorkingonWSUS of $AllWSUSCount) ..."
	    $cleanupManager = $WSUS.GetCleanupManager();
	    $cleanupManager.PerformCleanup($cleanupScope); 
    	write-host "Cleaning done for $WSUSServer ($WorkingonWSUS of $AllWSUSCount) ..."	-foregroundcolor Yellow
    }
    Catch [Exception] {
        write-host $_.Exception.GetType().FullName -foregroundcolor Red
	    write-host $_.Exception.Message -foregroundcolor Red
	    continue;
    }
}

Stop-Transcript
notepad $thisDir\$logFile