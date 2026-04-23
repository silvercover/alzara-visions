; ======================================================================
; Module : MergeVideo.pb
; Version: 1.4
; Purpose: Merge multiple MP4 files from a folder
; ======================================================================

Global Dim gFiles.s(0)
Global gFileCount = 0
Global gSourceFolder.s = ""
Global gLastSavePathMerge.s = ""
Global gCancelledMerge = #False
Global gShlwapi = 0
Global gSortAscending = #True

; =====================================================================
; LEVEL 0: No dependencies
; =====================================================================
Procedure NaturalCompare(a.s, b.s)
  Protected result
  If gShlwapi
    result = CallFunction(gShlwapi, "StrCmpLogicalW", @a, @b)
  Else
    Protected la.s = LCase(a), lb.s = LCase(b)
    If la < lb : result = -1 : ElseIf la > lb : result = 1 : Else : result = 0 : EndIf
  EndIf
  ProcedureReturn result
EndProcedure

Procedure HasNumber(fileName.s)
  Protected i
  For i = 1 To Len(fileName)
    If Mid(fileName, i, 1) >= "0" And Mid(fileName, i, 1) <= "9"
      ProcedureReturn #True
    EndIf
  Next
  ProcedureReturn #False
EndProcedure

Procedure.s FileSizeStr(bytes.q)
  If bytes >= 1073741824 : ProcedureReturn StrD(bytes / 1073741824.0, 2) + " GB"
  ElseIf bytes >= 1048576 : ProcedureReturn StrD(bytes / 1048576.0, 1) + " MB"
  ElseIf bytes >= 1024 : ProcedureReturn StrD(bytes / 1024.0, 1) + " KB"
  Else : ProcedureReturn Str(bytes) + " B" : EndIf
EndProcedure

; =====================================================================
; ForceSelectItem: force highlight using Windows API
; =====================================================================
Procedure ForceSelectItem(gadget, index)
  Protected hwnd = GadgetID(gadget)
  Protected lvi.LVITEM
  
  ; First deselect all
  lvi\stateMask = #LVIS_SELECTED | #LVIS_FOCUSED
  lvi\state = 0
  SendMessage_(hwnd, #LVM_SETITEMSTATE, -1, @lvi)
  
  ; Now select and focus the target item
  lvi\stateMask = #LVIS_SELECTED | #LVIS_FOCUSED
  lvi\state = #LVIS_SELECTED | #LVIS_FOCUSED
  SendMessage_(hwnd, #LVM_SETITEMSTATE, index, @lvi)
  
  ; Ensure visible
  SendMessage_(hwnd, #LVM_ENSUREVISIBLE, index, #False)
EndProcedure

; =====================================================================
; LEVEL 1: Sort functions (depend on NaturalCompare, HasNumber)
; =====================================================================
Procedure SortFilesNatural()
  If gFileCount < 2 : ProcedureReturn : EndIf
  Protected i, j, tmp.s
  Protected aHas, bHas, doSwap, cmp
  For i = 0 To gFileCount - 2
    For j = 0 To gFileCount - 2 - i
      aHas = HasNumber(gFiles(j))
      bHas = HasNumber(gFiles(j + 1))
      doSwap = #False
      If aHas And bHas
        cmp = NaturalCompare(gFiles(j), gFiles(j + 1))
        If cmp > 0 : doSwap = #True : EndIf
      ElseIf aHas = #False And bHas
        doSwap = #True
      ElseIf aHas = #False And bHas = #False
        cmp = NaturalCompare(gFiles(j), gFiles(j + 1))
        If cmp > 0 : doSwap = #True : EndIf
      EndIf
      If doSwap
        tmp = gFiles(j) : gFiles(j) = gFiles(j + 1) : gFiles(j + 1) = tmp
      EndIf
    Next
  Next
EndProcedure

Procedure SortFilesAZ()
  If gFileCount < 2 : ProcedureReturn : EndIf
  Protected i, j, tmp.s, cmp
  For i = 0 To gFileCount - 2
    For j = 0 To gFileCount - 2 - i
      cmp = NaturalCompare(gFiles(j), gFiles(j + 1))
      If cmp > 0
        tmp = gFiles(j) : gFiles(j) = gFiles(j + 1) : gFiles(j + 1) = tmp
      EndIf
    Next
  Next
EndProcedure

Procedure ReverseFiles()
  If gFileCount < 2 : ProcedureReturn : EndIf
  Protected i, half = gFileCount / 2
  Protected tmp.s
  For i = 0 To half - 1
    tmp = gFiles(i)
    gFiles(i) = gFiles(gFileCount - 1 - i)
    gFiles(gFileCount - 1 - i) = tmp
  Next
EndProcedure

; =====================================================================
; LEVEL 2: UI helpers
; =====================================================================
Procedure ApplyAlternateColors()
  Protected i
  For i = 0 To CountGadgetItems(#LIST_VIDEOS) - 1
    If i % 2 = 0
      SetGadgetItemColor(#LIST_VIDEOS, i, #PB_Gadget_BackColor, RGB(255, 255, 255))
    Else
      SetGadgetItemColor(#LIST_VIDEOS, i, #PB_Gadget_BackColor, RGB(240, 240, 240))
    EndIf
  Next
EndProcedure

Procedure UpdateSortButton()
  If gSortAscending
    SetGadgetText(#BTN_SORT_AZ, "A" + Chr($2193))
    SetGadgetColor(#BTN_SORT_AZ, #PB_Gadget_BackColor, RGB(200, 230, 255))
  Else
    SetGadgetText(#BTN_SORT_AZ, "Z" + Chr($2193))
    SetGadgetColor(#BTN_SORT_AZ, #PB_Gadget_BackColor, RGB(255, 220, 200))
  EndIf
EndProcedure

Procedure ResetSortButton()
  gSortAscending = #True
  SetGadgetText(#BTN_SORT_AZ, "A" + Chr($2193))
  SetGadgetColor(#BTN_SORT_AZ, #PB_Gadget_BackColor, RGB(240, 240, 240))
EndProcedure

Procedure RebuildList()
  Protected i
  Protected fSize.q
  ClearGadgetItems(#LIST_VIDEOS)
  For i = 0 To gFileCount - 1
    fSize = FileSize(gSourceFolder + gFiles(i))
    AddGadgetItem(#LIST_VIDEOS, -1, Str(i + 1) + Chr(10) + gFiles(i) + Chr(10) + FileSizeStr(fSize))
  Next
  ApplyAlternateColors()
EndProcedure

Procedure SwapListItems(idxA, idxB)
  If idxA < 0 Or idxA >= gFileCount : ProcedureReturn : EndIf
  If idxB < 0 Or idxB >= gFileCount : ProcedureReturn : EndIf
  Protected fSizeA.q = FileSize(gSourceFolder + gFiles(idxA))
  Protected fSizeB.q = FileSize(gSourceFolder + gFiles(idxB))
  SetGadgetItemText(#LIST_VIDEOS, idxA, Str(idxA + 1), 0)
  SetGadgetItemText(#LIST_VIDEOS, idxA, gFiles(idxA), 1)
  SetGadgetItemText(#LIST_VIDEOS, idxA, FileSizeStr(fSizeA), 2)
  SetGadgetItemText(#LIST_VIDEOS, idxB, Str(idxB + 1), 0)
  SetGadgetItemText(#LIST_VIDEOS, idxB, gFiles(idxB), 1)
  SetGadgetItemText(#LIST_VIDEOS, idxB, FileSizeStr(fSizeB), 2)
  If idxA % 2 = 0
    SetGadgetItemColor(#LIST_VIDEOS, idxA, #PB_Gadget_BackColor, RGB(255, 255, 255))
  Else
    SetGadgetItemColor(#LIST_VIDEOS, idxA, #PB_Gadget_BackColor, RGB(240, 240, 240))
  EndIf
  If idxB % 2 = 0
    SetGadgetItemColor(#LIST_VIDEOS, idxB, #PB_Gadget_BackColor, RGB(255, 255, 255))
  Else
    SetGadgetItemColor(#LIST_VIDEOS, idxB, #PB_Gadget_BackColor, RGB(240, 240, 240))
  EndIf
EndProcedure

; =====================================================================
; LEVEL 3: Actions
; =====================================================================
Procedure ScanFolder(folder.s)
  Protected dir, count, idx, i
  Protected unnumberedCount = 0, warnMsg.s
  Protected fSize.q
  Protected fileName.s, lowerName.s
  
  gFileCount = 0 : ReDim gFiles(0) : ClearGadgetItems(#LIST_VIDEOS)
  SetGadgetColor(#TXT_STATUS_MERGE, #PB_Gadget_FrontColor, RGB(0, 0, 0))
  SetGadgetState(#PROG_MERGE, 0) : DisableGadget(#BTN_MERGE, #True)
  HideGadget(#BTN_OPEN_FOLDER_MERGE, #True) : gLastSavePathMerge = ""
  ResetSortButton()
  
  count = 0
  dir = ExamineDirectory(#PB_Any, folder, "*.mp4")
  If dir
    While NextDirectoryEntry(dir)
      If DirectoryEntryType(dir) = #PB_DirectoryEntry_File
        lowerName = LCase(DirectoryEntryName(dir))
        If lowerName <> "merged_video.mp4" And Right(lowerName, 12) <> "_reduced.mp4"
          count + 1
        EndIf
      EndIf
    Wend
    FinishDirectory(dir)
  Else : SetGadgetText(#TXT_STATUS_MERGE, "Cannot open folder.") : ProcedureReturn : EndIf
  If count = 0 : SetGadgetText(#TXT_STATUS_MERGE, "No MP4 files found.") : ProcedureReturn : EndIf
  
  ReDim gFiles(count - 1) : gFileCount = count : idx = 0
  dir = ExamineDirectory(#PB_Any, folder, "*.mp4")
  If dir
    While NextDirectoryEntry(dir)
      If DirectoryEntryType(dir) = #PB_DirectoryEntry_File
        fileName = DirectoryEntryName(dir)
        lowerName = LCase(fileName)
        If lowerName <> "merged_video.mp4" And Right(lowerName, 12) <> "_reduced.mp4"
          gFiles(idx) = fileName : idx + 1
        EndIf
      EndIf
    Wend
    FinishDirectory(dir)
  EndIf
  
  SortFilesNatural()
  
  For i = 0 To gFileCount - 1
    fSize = FileSize(folder + gFiles(i))
    AddGadgetItem(#LIST_VIDEOS, -1, Str(i + 1) + Chr(10) + gFiles(i) + Chr(10) + FileSizeStr(fSize))
    If HasNumber(gFiles(i)) = #False : unnumberedCount + 1 : EndIf
  Next
  
  ApplyAlternateColors()
  DisableGadget(#BTN_MERGE, #False)
  
  If unnumberedCount > 0
    warnMsg = "Found " + Str(gFileCount) + " file(s). "
    warnMsg + Str(unnumberedCount) + " file(s) have no number and were placed at the end. "
    warnMsg + "Please verify the order."
    SetGadgetColor(#TXT_STATUS_MERGE, #PB_Gadget_FrontColor, RGB(180, 120, 0))
    SetGadgetText(#TXT_STATUS_MERGE, warnMsg)
  Else
    SetGadgetText(#TXT_STATUS_MERGE, "Found " + Str(gFileCount) + " file(s). Check order, then Start Merge.")
  EndIf
EndProcedure

Procedure MoveItemUp()
  Protected sel = GetGadgetState(#LIST_VIDEOS)
  If sel <= 0 Or sel >= gFileCount : ProcedureReturn : EndIf
  Protected tmp.s = gFiles(sel)
  gFiles(sel) = gFiles(sel - 1)
  gFiles(sel - 1) = tmp
  SwapListItems(sel - 1, sel)
  ForceSelectItem(#LIST_VIDEOS, sel - 1)
  ResetSortButton()
EndProcedure

Procedure MoveItemDown()
  Protected sel = GetGadgetState(#LIST_VIDEOS)
  If sel < 0 Or sel >= gFileCount - 1 : ProcedureReturn : EndIf
  Protected tmp.s = gFiles(sel)
  gFiles(sel) = gFiles(sel + 1)
  gFiles(sel + 1) = tmp
  SwapListItems(sel, sel + 1)
  ForceSelectItem(#LIST_VIDEOS, sel + 1)
  ResetSortButton()
EndProcedure

Procedure RemoveSelectedItem()
  Protected sel = GetGadgetState(#LIST_VIDEOS)
  If sel < 0 Or sel >= gFileCount : ProcedureReturn : EndIf
  Protected nextName.s = ""
  If sel < gFileCount - 1
    nextName = gFiles(sel + 1)
  ElseIf sel > 0
    nextName = gFiles(sel - 1)
  EndIf
  Protected i
  For i = sel To gFileCount - 2
    gFiles(i) = gFiles(i + 1)
  Next
  gFileCount - 1
  If gFileCount > 0 : ReDim gFiles(gFileCount - 1) : Else : ReDim gFiles(0) : EndIf
  RebuildList()
  If nextName <> "" And gFileCount > 0
    For i = 0 To gFileCount - 1
      If gFiles(i) = nextName
        ForceSelectItem(#LIST_VIDEOS, i)
        Break
      EndIf
    Next
  EndIf
  If gFileCount = 0
    DisableGadget(#BTN_MERGE, #True)
    SetGadgetText(#TXT_STATUS_MERGE, "List is empty.")
  Else
    SetGadgetText(#TXT_STATUS_MERGE, Str(gFileCount) + " file(s) in list.")
  EndIf
EndProcedure

Procedure ReloadFolder()
  If gSourceFolder <> "" : ScanFolder(gSourceFolder) : EndIf
EndProcedure

Procedure PlaySelectedVideo()
  Protected sel = GetGadgetState(#LIST_VIDEOS)
  If sel >= 0 And sel < gFileCount
    Protected filePath.s = gSourceFolder + gFiles(sel)
    If FileSize(filePath) > 0 : RunProgram(filePath, "", "") : EndIf
  EndIf
EndProcedure

; =====================================================================
; DoSortToggle: toggle between A->Z and Z->A
; =====================================================================
Procedure DoSortToggle()
  If gFileCount < 2 : ProcedureReturn : EndIf
  
  If gSortAscending
    ; Currently ascending or default -> sort A->Z
    SortFilesAZ()
    gSortAscending = #False
    SetGadgetColor(#TXT_STATUS_MERGE, #PB_Gadget_FrontColor, RGB(0, 0, 0))
    SetGadgetText(#TXT_STATUS_MERGE, Str(gFileCount) + " file(s). Sorted A " + Chr($2192) + " Z.")
  Else
    ; Currently A->Z -> reverse to Z->A
    ReverseFiles()
    gSortAscending = #True
    SetGadgetColor(#TXT_STATUS_MERGE, #PB_Gadget_FrontColor, RGB(0, 0, 0))
    SetGadgetText(#TXT_STATUS_MERGE, Str(gFileCount) + " file(s). Sorted Z " + Chr($2192) + " A.")
  EndIf
  
  RebuildList()
  UpdateSortButton()
EndProcedure

; =====================================================================
; LEVEL 4: DoMerge
; =====================================================================
Procedure DoMerge()
  Protected savePath.s, listFile.s, fid, i, safePath.s
  Protected batFile.s, errFile.s, proc, ev, line.s
  Protected timeUs.d, timeSec.d
  
  SetGadgetColor(#TXT_STATUS_MERGE, #PB_Gadget_FrontColor, RGB(0, 0, 0))
  SetGadgetState(#PROG_MERGE, 0) : HideGadget(#BTN_OPEN_FOLDER_MERGE, #True)
  gCancelledMerge = #False : gLastSavePathMerge = ""
  listFile = gTempDir + "alzara_concat.txt"
  
  If GetGadgetState(#CHK_CUSTOM_SAVE) = #PB_Checkbox_Checked
    savePath = SaveFileRequester("Save Merged Video As...", gSourceFolder + "Merged_Video.mp4", "MP4 (*.mp4)|*.mp4", 0)
    If savePath = "" : ProcedureReturn : EndIf
  Else : savePath = gSourceFolder + "Merged_Video.mp4" : EndIf
  
  fid = CreateFile(#PB_Any, listFile)
  If fid = 0 : MessageRequester("Error", "Cannot create temp file.") : ProcedureReturn : EndIf
  For i = 0 To gFileCount - 1
    safePath = ReplaceString(gSourceFolder + gFiles(i), "\", "/")
    WriteStringN(fid, "file '" + safePath + "'", #PB_UTF8)
  Next : CloseFile(fid)
  
  WriteLog("--- DoMerge ---")
  WriteLog("Concat: " + ReadEntireFile(listFile))
  
  DisableGadget(#BTN_MERGE, #True) : DisableGadget(#BTN_BROWSE, #True)
  DisableGadget(#BTN_MOVE_UP, #True) : DisableGadget(#BTN_MOVE_DOWN, #True)
  DisableGadget(#BTN_REMOVE_ITEM, #True) : DisableGadget(#BTN_RELOAD_LIST, #True)
  DisableGadget(#BTN_SORT_AZ, #True)
  HideGadget(#BTN_CANCEL_MERGE, #False) : SetGadgetText(#TXT_STATUS_MERGE, "Merging...")
  
  batFile = gTempDir + "alzara_merge.bat"
  errFile = gTempDir + "alzara_merge_err.txt"
  If FileSize(errFile) >= 0 : DeleteFile(errFile) : EndIf
  
  Protected ffArgs.s = "-y -f concat -safe 0 -i " + Chr(34) + listFile + Chr(34) + " -c copy -progress pipe:1 " + Chr(34) + savePath + Chr(34)
  Protected batCmd.s = Chr(34) + gFFmpegPath + Chr(34) + " " + ffArgs + " 2>" + Chr(34) + errFile + Chr(34)
  WriteLog("Cmd: " + batCmd)
  
  If WriteBatFile(batFile, batCmd) = ""
    MessageRequester("Error", "Cannot create bat file.")
    Goto mergeUnlock
  EndIf
  
  Protected cmdArgs.s = "/c " + Chr(34) + batFile + Chr(34)
  Protected workDir.s = gTempDir
  proc = RunProgram("cmd.exe", cmdArgs, workDir, #PB_Program_Open | #PB_Program_Read | #PB_Program_Hide)
  If proc = 0
    MessageRequester("Error", "Cannot run ffmpeg!")
    Goto mergeUnlock
  EndIf
  
  While ProgramRunning(proc)
    While AvailableProgramOutput(proc)
      line = ReadProgramString(proc)
      If Left(line, 12) = "out_time_ms="
        timeUs = ValD(Mid(line, 13)) : timeSec = timeUs / 1000000.0
        SetGadgetText(#TXT_STATUS_MERGE, "Merging... " + Str(Int(timeSec / 60)) + "m " + Str(Int(timeSec) % 60) + "s")
      EndIf
    Wend
    Repeat : ev = WindowEvent()
      If ev = #PB_Event_Gadget And EventGadget() = #BTN_CANCEL_MERGE : gCancelledMerge = #True : KillFFmpeg() : KillProgram(proc) : EndIf
      If ev = #PB_Event_CloseWindow : KillFFmpeg() : KillProgram(proc) : CloseProgram(proc) : End : EndIf
    Until ev = 0
    If gCancelledMerge : Break : EndIf : Delay(50)
  Wend
  While AvailableProgramOutput(proc) : ReadProgramString(proc) : Wend : CloseProgram(proc)
  
  Protected errContent.s = ReadEntireFile(errFile)
  If Len(errContent) > 0 : WriteLog("stderr: " + Left(errContent, 2000)) : EndIf
  
  If gCancelledMerge
    SetGadgetColor(#TXT_STATUS_MERGE, #PB_Gadget_FrontColor, RGB(200, 0, 0))
    SetGadgetText(#TXT_STATUS_MERGE, "Operation Cancelled!") : Delay(500)
    If FileSize(savePath) >= 0 : DeleteFile(savePath) : EndIf
  ElseIf FileSize(savePath) <= 0
    SetGadgetColor(#TXT_STATUS_MERGE, #PB_Gadget_FrontColor, RGB(200, 0, 0))
    SetGadgetText(#TXT_STATUS_MERGE, "Error! Check log for details.")
    WriteLog("MERGE FAILED. stderr: " + errContent)
  Else
    gLastSavePathMerge = savePath : SetGadgetState(#PROG_MERGE, 100)
    SetGadgetColor(#TXT_STATUS_MERGE, #PB_Gadget_FrontColor, RGB(0, 160, 0))
    SetGadgetText(#TXT_STATUS_MERGE, "By the Great Alzara!")
    HideGadget(#BTN_OPEN_FOLDER_MERGE, #False)
    MessageRequester(#APP_TITLE, "Merge completed!" + #CRLF$ + "Saved: " + savePath)
  EndIf
  
  mergeUnlock:
  DisableGadget(#BTN_MERGE, #False) : DisableGadget(#BTN_BROWSE, #False)
  DisableGadget(#BTN_MOVE_UP, #False) : DisableGadget(#BTN_MOVE_DOWN, #False)
  DisableGadget(#BTN_REMOVE_ITEM, #False) : DisableGadget(#BTN_RELOAD_LIST, #False)
  DisableGadget(#BTN_SORT_AZ, #False)
  HideGadget(#BTN_CANCEL_MERGE, #True)
  DeleteFile(listFile) : DeleteFile(batFile) : DeleteFile(errFile)
EndProcedure

; IDE Options = PureBasic 6.20 (Windows - x64)
; CursorPosition = 437
; FirstLine = 384
; Folding = ----
; EnableXP
; DPIAware