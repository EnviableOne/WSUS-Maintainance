# WSUS-Maintainance
Powershell Module to Audit and Maintain WSUS In an enterprise environment

This is a collection of Powershell Scripts with specific tasks to maintain the WSUS configuration
the originals were posted By Nitesh Kumar on his blog https://nitishkumar.net/ 
the functions of them are largley unchanged, a lot of variables have been renamed for clarity, and a few modifications have been made to improve error handling and speed. The remaining script(s) have been inspired by the originals, but are all my own work.

# WSUS-Audit
this script generates reports based on the Update deployment state of each server and each target connected to them

# WSUS-Cleanup
This script performs The WSUS Clean-up on all Servers and provides a report of the results

# WSUS-Tidy
This Script Identifies information on WSUS servers that does not relate to Machines joined to the domain and optionally removes them from each WSUS Server

# Licence
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
