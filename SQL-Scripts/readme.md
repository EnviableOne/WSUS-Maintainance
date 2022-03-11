# SUSDB SQL-Queries<br>
the following SQL scripts wer collected from microsoft and various individuals, and perform optimisations and cleanup operations directly on the SUSDB database within the Windows Internal Database.

* **WSUS-AddIndexes**<br>
this Query adds some indexes to optimise update lookup

* **WSUS-ReIndex**<br>
this Query cleans-up the indexes to optimise performance

* **WSUS-Delete-Obsolete**<br>
This Query works on the database directly to remove updates are no longer needs, if the WSUS-Cleanup script or clean-up routine in the console is struggling to complete, this works to remove the updates directly and should only be used if maintainance has not been done in a long time, or if a large number of updates need to be removed.

* **WSUS-Count-Updates**<br>
This query returns a summary of the updates in various states in the database to identify wherte the problems may exist

* **Feed my Caffine Addiction**<BR>
if any of this is useful : [![ko-fi](https://www.ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/Z8Z21XJ08)
