# WSUS-Maintainance
Powershell scripts to Audit and Maintain WSUS In an enterprise environment

This is a collection of Powershell Scripts with specific tasks to maintain the WSUS configuration the originals were posted By Nitish Kumar on his blog https://nitishkumar.net/ (marked with \*) the functions of them are largley unchanged, a lot of variables have been renamed for clarity, and modifications have been made to improve error handling and speed. <br><br>
The remaining script(s) are my work that have been inspired by the originals, or other WSUS Scripts collected and attributed to their authors<br><br>
These Scripts work considerably better when regular maintainance on the WSUS Database has been carried out as Per: <br>
https://docs.microsoft.com/en-us/troubleshoot/mem/configmgr/wsus-maintenance-guide

* **WSUS-Audit\***<br>
this script generates reports based on the Update deployment state of each server and each target connected to them

* **WSUS-Cleanup\***<br>
This script performs a customisable WSUS Clean-up on all Servers and provides a report of the results

* **WSUS-Tidy**<br>
This Script Identifies information on WSUS servers that does not relate to Machines joined to the AD domain and optionally removes them from each WSUS Server

* **WSUS-Approvals**<br>
This script collects information from WSUS servers to track delay between release, approval and Installation.
The installation date is taken from the last install summary, so might not be close enough, but the best i could do without connecting to the targets individualy

* **Get-WSUS-Settings**<br>
This Script shows the Update Settings on a specified machine

* **Get-WSUS-AppPoolSettings**<br>
This script connects remotley to WSUS Servers and checks the IIS Settings for comparison against Best Practice

* **Licence**<br>
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

* **Feed my Caffine Addiction**<BR>
if any of this is useful : [![ko-fi](https://www.ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/Z8Z21XJ08)
