# SUSDB SQL-Queries<br>
The following SQL scripts were collected from Microsoft and various individuals, and perform optimisations and cleanup operations directly on the SUSDB database within the Windows Internal Database.

* **SUSBD-AddIndexes**<br>
This query adds some indexes to optimise update lookup

* **SUSDB-ReIndex**<br>
This query cleans up the indexes to optimise performance

* **SUSDB-Delete-Obsolete**<br>
This Query works on the database directly to remove updates are no longer needs, if the WSUS-Cleanup script or clean-up routine in the console is struggling to complete, this works to remove the updates directly and should only be used if maintainance has not been done in a long time, or if a large number of updates need to be removed.

* **SUSDB-Count-Updates**<br>
This query returns a summary of the updates in various states in the database to identify where the problems may exist

* **Feed my Caffine Addiction**<BR>
if any of this is useful : [![ko-fi](https://www.ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/Z8Z21XJ08)
