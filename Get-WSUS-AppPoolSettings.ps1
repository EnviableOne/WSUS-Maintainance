<#
.SYNOPSIS
    This script performs an audit on the IIS Application Pool settings 
    for WSUS servers in the Local Domain
 
.DESCRIPTION
    This Script uses the PS remoting to connect to each listed server 
    and load the Microsoft.system.WebAdministration module and get
    the settings refered to in various Best Practice Guides for WSUS.
    It then gets the http runtime settings from the client web config
    before passing this back to the host machine.
    
    The host machine optionally outputs this to a file or displays it
    as a data table on the host computer
     
.INPUTS
    $WSUSServers List of WSUS Server names (must be resovable)
    $ReportPath  where to create the reports
    $AdmCreds Credentials to remote to the WSUS Servers
    $
 
.OUTPUTS
    $Results is a custom object containing the settings for each WSUS
    Server which dependant on the $ToFile switch is output either as a
    table or a comma seperated variable file as below:
    
    WSUSAppPoolSettings_<RUNTIME>.csv

    in the folder specified in the $ReportPath variable
 
.NOTES
    Author        Version   Date
    Peter Marquis 1.0       25 January 2021
    
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
    Version 1.0 - https://github.com/EnviableOne/WSUS-Maintainance
#>
[cmdletbinding()]
Param(
[switch]$Tofile=$false
)

# WSUS servers in environment
$WSUSServers = $AllWSUSServers
#$WSUSServers = ("wsus-pcs3")

#Initialise Variables
$Results = @()
$CurrentServer=0
$ServerCount = $WSUSServers.Count
$ReportPath = "D:\wsus-reports"
$dateText = (Get-Date).ToString('MM-dd-yyyy_hh-mm-ss')
$AdmCreds = (Get-Credential -Message "Please Enter Valid Credentials to Access WSUS Servers")

ForEach ($WSUSServer in $WSUSServers) {		
 $CurrentServer++
 write-host "Connecting to $WSUSServer (Server $CurrentServer of $ServerCount) ... "	-foregroundcolor Green -NoNewline
 Try{
  $sess = New-PSSession -ComputerName $WSUSServer -Credential $AdmCreds -ErrorAction Stop
  Write-host "Connected and Fetching config ... " -ForegroundColor Gray -NoNewline
 }
 Catch {
  Write-host "failed" -ForegroundColor Red
  continue
 }
 
 $config = Invoke-command -Session $sess -ScriptBlock {
  Import-module WebAdministration
  $Pool = Get-ItemProperty -Path IIS:\AppPools\WSUSPool
  Try {
   $mem1 = (Get-WmiObject -class Win32_PhysicalMemory -Property Capacity).Capacity
   If ($mem1.count -gt 1){
    $sum=0
    $mem1 | %{$sum += $_}
    $mem1=$sum
   }
  }
  Catch{
   $mem1 = 0
  }
  Try {
   $mem2 = (Get-WmiObject -class Win32_ComputerSystem -Property TotalPhysicalMemory).TotalPhysicalMemory
  }
  Catch {
   $mem2 = 0
  }
  $Mem = [System.Math]::Max($mem1,$mem2) /1024/1024/1024 #Convert to GB
  [Xml]$XMLConf = gc 'C:\Program Files\Update Services\webservices\ClientWebService\Web.config'
  $MaxReq = $xmlconf.configuration.'system.web'.httpRuntime.maxRequestLength
  $ExecTim = $xmlconf.configuration.'system.web'.httpRuntime.executionTimeout
  $OSVER = (Get-CimInstance Win32_OperatingSystem).version
  $IISVER = [System.Diagnostics.FileVersionInfo]::GetVersionInfo("$env:SystemRoot\system32\inetsrv\InetMgr.exe").ProductVersion
  $Config = New-Object psobject
   $Config | Add-Member -MemberType NoteProperty -Name ServerName -Value $using:WSUSServer
   $Config | Add-Member -MemberType NoteProperty -Name QueueLength -Value $pool.queueLength
   $Config | Add-Member -MemberType NoteProperty -Name IdleTimeout -Value $pool.processModel.idleTimeout.Minutes
   $Config | Add-Member -MemberType NoteProperty -Name PingEnabled -Value $pool.processModel.pingingEnabled
   $Config | Add-Member -MemberType NoteProperty -Name PvtMemLimit -Value $pool.recycling.periodicRestart.privateMemory
   $Config | Add-Member -MemberType NoteProperty -Name RegTimeInt -Value $pool.recycling.periodicRestart.time.minutes
   $Config | Add-Member -MemberType NoteProperty -Name RamGB -Value $mem
   $Config | Add-Member -MemberType NoteProperty -Name MaxReqLen -value $MaxReq
   $Config | Add-Member -MemberType NoteProperty -Name ExecTimeout -Value $ExecTim
   $Config | Add-Member -MemberType NoteProperty -Name IISVer -Value $IISVER
   $config | Add-Member -MemberType NoteProperty -Name OSVer -Value $OSVER
  $Config
 } -HideComputerName
 $Results += $Config
 Remove-PSSession $sess
 write-Host "done"
}
$out = $Results | Select ServerName,QueueLength,IdleTimeout,PingEnabled,PvtMemLimit,RegTimeInt,RamGB,MaxReqLen,ExecTimeout,IISVer,OSVer
If(!$ToFile){
 $out | ft -AutoSize
}
Else {
 $out | Export-csv -Path "$Reportpath\WSUSAppPoolSettings_$datetext.csv" -NoTypeInformation -Append
}
