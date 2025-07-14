# SUSDB SQL-Queries<br>
The following SQL scripts were collected from Microsoft and various individuals, and perform optimisations and cleanup operations directly on the SUSDB database within the Windows Internal Database.

* **SUSBD-CreateIndexes**<br>
This query adds some indexes to optimise update lookup

* **SUSDB-ReIndex-Defrag**<br>
This query cleans up the indexes to optimise performance and speed up update handling processes

* **SUSDB-Delete-Obsolete**<br>
This Query works on the database directly to remove updates that are no longer needed, if the WSUS-Cleanup script or clean-up routine in the console is struggling to complete.
This removes the updates directly from the DB and should only be used if maintenance has not been done in a long time, or if a large number of updates need to be removed.

* **SUSDB-Count-Superseded**<br>
This query returns a summary of the updates in various states in the database to identify where the problems may exist

* **SUSDB-Decline-Superseded**<br>
This query marks all superseded updates as Declined so they can be removed from the local cache

* **SUSDB-SpeedUpDeleteUpdate**<br>
This query replaces the [dbo].[spDeleteUpdate] stored procedure with a more optimised version

* **Feed my Caffine Addiction**<BR>
if any of this is useful : [![ko-fi](https://www.ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/Z8Z21XJ08)
