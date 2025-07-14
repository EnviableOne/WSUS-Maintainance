-- Decline superseded updates in SUSDB; alternative to Decline-SupersededUpdatesWithExclusionPeriod.ps1
DECLARE @thresholdDays INT = 90 -- Specify the number of days between today and the release date for which the superseded updates must not be declined (i.e., updates older than 90 days). This should match configuration of supersedence rules in SUP component properties, if ConfigMgr is being used with WSUS.
DECLARE @testRun BIT = 0 -- Set this to 1 to test without declining anything.
-- There shouldn't be any need to modify anything after this line.

DECLARE @uid UNIQUEIDENTIFIER
DECLARE @title NVARCHAR(500)
DECLARE @date DATETIME
DECLARE @userName NVARCHAR(100) = SYSTEM_USER

DECLARE @count INT = 0

DECLARE DU CURSOR FOR
  SELECT MU.UpdateID, U.DefaultTitle, U.CreationDate FROM vwMinimalUpdate MU
  JOIN PUBLIC_VIEWS.vUpdate U ON MU.UpdateID = U.UpdateId
WHERE MU.IsSuperseded = 1 AND MU.Declined = 0 AND MU.IsLatestRevision = 1
  AND MU.CreationDate < DATEADD(dd,-@thresholdDays,GETDATE())
ORDER BY MU.CreationDate

PRINT 'Declining superseded updates older than ' + CONVERT(NVARCHAR(5), @thresholdDays) + ' days.' + CHAR(10)

OPEN DU
FETCH NEXT FROM DU INTO @uid, @title, @date
WHILE (@@FETCH_STATUS > - 1)
BEGIN
  SET @count = @count + 1
  PRINT 'Declining update ' + CONVERT(NVARCHAR(50), @uid) + ' (Creation Date ' + CONVERT(NVARCHAR(50), @date) + ') - ' + @title + ' ...'
  IF @testRun = 0
     EXEC spDeclineUpdate @updateID = @uid, @adminName = @userName, @failIfReplica = 1
  FETCH NEXT FROM DU INTO @uid, @title, @date
END

CLOSE DU
DEALLOCATE DU

PRINT CHAR(10) + 'Attempted to decline ' + CONVERT(NVARCHAR(10), @count) + ' updates.'