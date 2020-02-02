@ECHO OFF
SET PatchedFile="gcpatched.swf"
SET BackupFile="GemCraft Frostborn Wrath Backup.swf"
SET DiffFile="Gemsmith-1.6-for-1.0.18a.diff"

IF EXIST %BackupFile% GOTO PerformPatch
copy /y "GemCraft Frostborn Wrath.swf" "GemCraft Frostborn Wrath Backup.swf"

:PerformPatch
courgette64.exe -apply "GemCraft Frostborn Wrath Backup.swf" %DiffFile% %PatchedFile%

IF EXIST %PatchedFile% GOTO ReplaceOldSwf
GOTO ERROR

:ReplaceOldSwf
del "GemCraft Frostborn Wrath.swf"
ren "gcpatched.swf" "GemCraft Frostborn Wrath.swf"
del "courgette.log"
del %DiffFile%
del "courgette64.exe"

ECHO Patch successful! All unnecessary files have been deleted.
ECHO A backup of your unmodded .swf has been created: %BackupFile%
ECHO You can launch the game normally from steam.
ECHO Have fun!
PAUSE

REM Next line makes this .bat delete itself
goto 2>nul & del "%~f0"
EXIT

:ERROR
ECHO ERROR: Couldn't apply the patch!
ECHO This means that your %BackupFile% was not the one expected by the patcher. Most likely that's because there's been a game update.
ECHO Try deleting your %BackupFile% and applying the patch again.
ECHO If the error still occurs, make sure you're using an unmodded swf and your game version matches the "for" part of %DiffFile% version.
PAUSE
EXIT