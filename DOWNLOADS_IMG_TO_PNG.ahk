#Requires AutoHotkey v2.0
#SingleInstance Force

/* CONFIGURATION 
    Retrieves the actual path of the User Downloads folder from the Windows Registry.
    This ensures the script works even if the folder has been moved to another drive.
*/
RegPath := "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"
; {374DE290-123F-4565-9164-39C4925E467B} is the unique ID for the Downloads folder
DownloadFolder := RegRead(RegPath, "{374DE290-123F-4565-9164-39C4925E467B}")

/* PATH SANITIZATION
    Expand environment variables like %USERPROFILE% if present in the registry string.
*/
DownloadFolder := ComObject("WScript.Shell").ExpandEnvironmentStrings(DownloadFolder)

/* TIMER SETTINGS
    Checks for new files every 2000 milliseconds (2 seconds).
*/
SetTimer(MonitorDownloads, 2000)

MonitorDownloads() {
    Loop Files, DownloadFolder "\*.*"
    {
        if (A_LoopFileExt = "webp" || A_LoopFileExt = "avif") {
            OriginalFile := A_LoopFileFullPath
            OutputFile := RegExReplace(OriginalFile, "\.(webp|avif)$", ".png")
            
            ; Executes ffmpeg.exe (must be in system PATH)
            ExitStatus := RunWait('ffmpeg.exe -i "' OriginalFile '" -y "' OutputFile '"', , "Hide")
            
            ; Delete original file only if conversion was successful
            if (ExitStatus = 0) {
                FileDelete(OriginalFile)
            }
        }
    }
}
