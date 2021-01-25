# WSUS-Maintainance
Powershell scripts to Audit and Maintain WSUS In an enterprise environment

This is a collection of Powershell Scripts with specific tasks to maintain the WSUS configuration
the originals were posted By Nitish Kumar on his blog https://nitishkumar.net/ (marked with \*)
the functions of them are largley unchanged, a lot of variables have been renamed for clarity, and modifications have been made to improve error handling and speed. <br>
The remaining script(s) have been inspired by the originals, are my work, or those attributed<br>
These Scripts work considerably better when regular maintainance on the WSUS Database has been carried out as Per: <br>
https://docs.microsoft.com/en-us/troubleshoot/mem/configmgr/wsus-maintenance-guide

# WSUS-Audit\*
this script generates reports based on the Update deployment state of each server and each target connected to them

# WSUS-Cleanup\*
This script performs a customisable WSUS Clean-up on all Servers and provides a report of the results

# WSUS-Tidy
This Script Identifies information on WSUS servers that does not relate to Machines joined to the AD domain and optionally removes them from each WSUS Server

# Get-WSUS-Settings
This Script shows the Update Settings on a specified machine

# Get-WSUS-AppPoolSettings
This scriptchecks the IIS Settings of listed WSUS Servers for comparison against Best Practice

# Licence
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

# Feed my Caffine Addiction
if any of this is useful : [![ko-fi](https://www.ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/Z8Z21XJ08)
