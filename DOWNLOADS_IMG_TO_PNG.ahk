#Requires AutoHotkey v2.0
#SingleInstance Force

; Configuration: Retrieve the Downloads folder path from the Windows Registry
; This ensures the script finds the correct path even if the user moved the folder
RegPath := "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"
DownloadFolder := RegRead(RegPath, "{374DE290-123F-4565-9164-39C4925E467B}")
DownloadFolder := ComObject("WScript.Shell").ExpandEnvironmentStrings(DownloadFolder)

; API Call: Create a handle to the directory with backup semantics to allow monitoring
; FILE_LIST_DIRECTORY (1), FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE (7)
; OPEN_EXISTING (3), FILE_FLAG_BACKUP_SEMANTICS (0x02000000)
hDir := DllCall("CreateFile", "Str", DownloadFolder, "UInt", 1, "UInt", 7, "Ptr", 0, "UInt", 3, "UInt", 0x02000000, "Ptr", 0, "Ptr")

if (hDir = -1)
	ExitApp()

; Data buffers for the ReadDirectoryChangesW API
BufferObj := Buffer(1024)
BytesReturned := Buffer(4)

; Infinite loop that waits for file system notifications
Loop {
	; ReadDirectoryChangesW blocks the thread until a change occurs (FILE_NOTIFY_CHANGE_FILE_NAME | FILE_NOTIFY_CHANGE_LAST_WRITE)
	if DllCall("ReadDirectoryChangesW", "Ptr", hDir, "Ptr", BufferObj, "UInt", BufferObj.Size, "Int", 0, "UInt", 0x1 | 0x10, "Ptr", BytesReturned, "Ptr", 0, "Ptr", 0) {
		Offset := 0
		Loop {
			; Extract the file name length and the name itself from the pointer buffer
			NextEntry := NumGet(BufferObj, Offset, "UInt")
			FileNameLen := NumGet(BufferObj, Offset + 8, "UInt")
			FileName := StrGet(BufferObj.Ptr + Offset + 12, FileNameLen / 2, "UTF-16")
			
			; Extract file extension for filtering
			Extension := StrLower(RegExReplace(FileName, ".*\.(\w+)$", "$1"))
			
			; Processing target extensions: webp and avif
			if (Extension = "webp" || Extension = "avif") {
				FullOriginalPath := DownloadFolder "\" FileName
				FullOutputPath := RegExReplace(FullOriginalPath, "\.(webp|avif)$", ".png")
				
				; Check if the file still exists and wait for the browser to release the file handle
				if FileExist(FullOriginalPath) {
					Sleep(500)
					; Execute ffmpeg conversion in hidden mode
					ExitStatus := RunWait('ffmpeg.exe -i "' FullOriginalPath '" -y "' FullOutputPath '"', , "Hide")
					
					; Delete the original source file only if the conversion exit code is 0 (success)
					if (ExitStatus = 0) {
						FileDelete(FullOriginalPath)
					}
				}
			}
			
			; Move to the next entry in the notification buffer or exit the loop
			if (NextEntry = 0)
				break
			Offset += NextEntry
		}
	}
}
