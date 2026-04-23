; ======================================================================
; Module : ImageConvert.pb
; Purpose: Image format conversion (HEIC, PNG, WEBP, BMP, TIFF -> JPG/PNG/WEBP)
; Usage  : XIncludeFile "ImageConvert.pb" in main file
; Backend: ffmpeg.exe
; ======================================================================

; --- Globals for Image Convert tab ---
Global gImgInputMode = 0          ; 0=Single File, 1=Folder
Global gImgInputPath.s = ""
Global gImgFolderPath.s = ""
Global gImgLastSavePath.s = ""
Global gImgCancelled = #False
Global Dim gImgFiles.s(0)
Global gImgFileCount = 0

; Supported input extensions
#IMG_INPUT_EXTS = "heic|heif|png|webp|bmp|tiff|tif"

; =====================================================================
; Check if file extension is a supported image input
; =====================================================================
Procedure IsImageSupported(fileName.s)
  Protected ext.s = LCase(GetExtensionPart(fileName))
  If ext = "heic" Or ext = "heif" Or ext = "png" Or ext = "webp" Or ext = "bmp" Or ext = "tiff" Or ext = "tif"
    ProcedureReturn #True
  EndIf
  ProcedureReturn #False
EndProcedure

; =====================================================================
; Get output extension from combo selection
; =====================================================================
Procedure.s GetImgOutputExt(formatIdx)
  Select formatIdx
    Case 0 : ProcedureReturn "jpg"
    Case 1 : ProcedureReturn "png"
    Case 2 : ProcedureReturn "webp"
    Default : ProcedureReturn "jpg"
  EndSelect
EndProcedure

; =====================================================================
; Build ffmpeg args for single image conversion
; =====================================================================
Procedure.s BuildImageConvertArgs(inputFile.s, outputFile.s, formatIdx, quality)
  Protected args.s = "-y -loglevel quiet -i " + Chr(34) + inputFile + Chr(34)
  Protected outExt.s = GetImgOutputExt(formatIdx)
  
  ; -update 1 is needed for single image output
  args + " -update 1"
  
  Select outExt
    Case "jpg"
      ; -q:v 2-31 for MJPEG (2=best, 31=worst)
      ; Map quality 100->2, 1->31
      Protected qv = 2 + Round((100 - quality) * 29.0 / 99.0, #PB_Round_Nearest)
      If qv < 2 : qv = 2 : EndIf
      If qv > 31 : qv = 31 : EndIf
      args + " -q:v " + Str(qv)
    Case "png"
      ; PNG is lossless, no quality setting needed
      ; -compression_level 6 is default (0-9)
      args + " -compression_level 6"
    Case "webp"
      ; -quality 0-100 for WebP
      args + " -quality " + Str(quality)
  EndSelect
  
  args + " " + Chr(34) + outputFile + Chr(34)
  ProcedureReturn args
EndProcedure

; =====================================================================
; Scan folder for supported image files
; =====================================================================
Procedure ScanImageFolder(folder.s)
  Protected dir, count = 0, idx = 0
  
  gImgFileCount = 0
  ReDim gImgFiles(0)
  
  ; First pass: count files
  dir = ExamineDirectory(#PB_Any, folder, "*.*")
  If dir
    While NextDirectoryEntry(dir)
      If DirectoryEntryType(dir) = #PB_DirectoryEntry_File
        If IsImageSupported(DirectoryEntryName(dir))
          count + 1
        EndIf
      EndIf
    Wend
    FinishDirectory(dir)
  EndIf
  
  If count = 0 : ProcedureReturn 0 : EndIf
  
  ReDim gImgFiles(count - 1)
  gImgFileCount = count
  
  ; Second pass: collect filenames
  dir = ExamineDirectory(#PB_Any, folder, "*.*")
  If dir
    While NextDirectoryEntry(dir)
      If DirectoryEntryType(dir) = #PB_DirectoryEntry_File
        If IsImageSupported(DirectoryEntryName(dir))
          gImgFiles(idx) = DirectoryEntryName(dir)
          idx + 1
        EndIf
      EndIf
    Wend
    FinishDirectory(dir)
  EndIf
  
  ProcedureReturn count
EndProcedure

; =====================================================================
; ConvertSingleImage: FIXED - two-pass for HEIC
; =====================================================================
Procedure ConvertSingleImage(inputFile.s, outputFile.s, formatIdx, quality)
  Protected args.s, proc, ev
  Protected batFile.s, errFile.s, errContent.s
  Protected outExt.s = GetImgOutputExt(formatIdx)
  Protected isHEIC = #False
  Protected inExt.s = LCase(GetExtensionPart(inputFile))
  
  If inExt = "heic" Or inExt = "heif" : isHEIC = #True : EndIf
  
  ; For HEIC: just decode to output format (no -vf needed)
  ; ffmpeg handles the complex filtergraph internally
  args = "-y -i " + Chr(34) + inputFile + Chr(34) + " -update 1 -frames:v 1"
  
  Select outExt
    Case "jpg"
      Protected qv = 2 + Round((100 - quality) * 29.0 / 99.0, #PB_Round_Nearest)
      If qv < 2 : qv = 2 : EndIf
      If qv > 31 : qv = 31 : EndIf
      args + " -q:v " + Str(qv)
    Case "png"
      args + " -compression_level 6"
    Case "webp"
      args + " -quality " + Str(quality)
  EndSelect
  
  args + " " + Chr(34) + outputFile + Chr(34)
  WriteLog("ImgConvert: " + args)
  
  batFile = gTempDir + "alzara_imgconv.bat"
  errFile = gTempDir + "alzara_imgconv_err.txt"
  If FileSize(errFile) >= 0 : DeleteFile(errFile) : EndIf
  
  Protected batCmd.s = Chr(34) + gFFmpegPath + Chr(34) + " " + args + " 2>" + Chr(34) + errFile + Chr(34)
  If WriteBatFile(batFile, batCmd) = ""
    WriteLog("ImgConvert ERROR: Cannot create bat")
    ProcedureReturn #False
  EndIf
  
  proc = RunProgram("cmd.exe", "/c " + Chr(34) + batFile + Chr(34), gTempDir, #PB_Program_Open | #PB_Program_Hide)
  If proc = 0
    WriteLog("ImgConvert ERROR: Cannot run ffmpeg")
    ProcedureReturn #False
  EndIf
  
  While ProgramRunning(proc)
    Repeat
      ev = WindowEvent()
      If ev = #PB_Event_Gadget And EventGadget() = #BTN_CANCEL_IMG
        gImgCancelled = #True : KillFFmpeg() : KillProgram(proc)
      EndIf
      If ev = #PB_Event_CloseWindow : KillFFmpeg() : KillProgram(proc) : CloseProgram(proc) : End : EndIf
    Until ev = 0
    If gImgCancelled : Break : EndIf
    Delay(20)
  Wend
  CloseProgram(proc)
  
  errContent = ReadEntireFile(errFile)
  If Len(errContent) > 0 : WriteLog("ImgConvert stderr: " + Left(errContent, 500)) : EndIf
  DeleteFile(batFile) : DeleteFile(errFile)
  
  If gImgCancelled : ProcedureReturn #False : EndIf
  If FileSize(outputFile) > 0 : ProcedureReturn #True : EndIf
  WriteLog("ImgConvert FAILED: " + inputFile)
  ProcedureReturn #False
EndProcedure

; =====================================================================
; DoImageConvert: main conversion procedure
; =====================================================================
Procedure DoImageConvert()
  Protected formatIdx, quality, outExt.s
  Protected savePath.s, saveFolder.s
  Protected i, successCount = 0, failCount = 0
  Protected inputFile.s, outputFile.s
  Protected baseName.s, baseFolder.s
  Protected progressPct
  
  formatIdx = GetGadgetState(#COMBO_IMG_FORMAT)
  quality = GetGadgetState(#TRACK_IMG_QUALITY)
  outExt = GetImgOutputExt(formatIdx)
  
  SetGadgetColor(#TXT_STATUS_IMG, #PB_Gadget_FrontColor, RGB(0, 0, 0))
  SetGadgetState(#PROG_IMG, 0)
  HideGadget(#BTN_OPEN_FOLDER_IMG, #True)
  gImgCancelled = #False : gImgLastSavePath = ""
  
  ; Determine input mode
  Protected mode = GetGadgetState(#COMBO_IMG_MODE)
  
  If mode = 0
    ; --- Single File Mode ---
    If gImgInputPath = ""
      MessageRequester("Alzara Vision", "Please select an input file.")
      ProcedureReturn
    EndIf
    
    baseName = GetFilePart(gImgInputPath, #PB_FileSystem_NoExtension)
    baseFolder = GetPathPart(gImgInputPath)
    
    If Bool(GetGadgetState(#CHK_CUSTOM_SAVE_IMG) = #PB_Checkbox_Checked)
      savePath = SaveFileRequester("Save Image As...", baseFolder + baseName + "." + outExt, UCase(outExt) + " (*." + outExt + ")|*." + outExt, 0)
      If savePath = "" : ProcedureReturn : EndIf
    Else
      savePath = baseFolder + baseName + "." + outExt
    EndIf
    
    DisableGadget(#BTN_IMG_CONVERT, #True) : DisableGadget(#BTN_BROWSE_IMG, #True)
    HideGadget(#BTN_CANCEL_IMG, #False)
    SetGadgetText(#TXT_STATUS_IMG, "Converting...")
    SetGadgetState(#PROG_IMG, 50)
    
    If ConvertSingleImage(gImgInputPath, savePath, formatIdx, quality)
      gImgLastSavePath = savePath
      SetGadgetState(#PROG_IMG, 100)
      SetGadgetColor(#TXT_STATUS_IMG, #PB_Gadget_FrontColor, RGB(0, 160, 0))
      SetGadgetText(#TXT_STATUS_IMG, "By the Great Alzara!  (" + FormatFileSize(FileSize(savePath)) + ")")
      HideGadget(#BTN_OPEN_FOLDER_IMG, #False)
      MessageRequester(#APP_TITLE, "Image converted!" + #CRLF$ + "Saved: " + savePath)
    ElseIf gImgCancelled
      SetGadgetColor(#TXT_STATUS_IMG, #PB_Gadget_FrontColor, RGB(200, 0, 0))
      SetGadgetText(#TXT_STATUS_IMG, "Operation Cancelled!")
      If FileSize(savePath) >= 0 : DeleteFile(savePath) : EndIf
    Else
      SetGadgetColor(#TXT_STATUS_IMG, #PB_Gadget_FrontColor, RGB(200, 0, 0))
      SetGadgetText(#TXT_STATUS_IMG, "Error converting image!")
    EndIf
    
  Else
    ; --- Folder (Batch) Mode ---
    If gImgFolderPath = ""
      MessageRequester("Alzara Vision", "Please select a folder.")
      ProcedureReturn
    EndIf
    
    Protected fileCount = ScanImageFolder(gImgFolderPath)
    If fileCount = 0
      MessageRequester("Alzara Vision", "No supported image files found in folder.")
      ProcedureReturn
    EndIf
    
    ; Determine output folder
    If Bool(GetGadgetState(#CHK_CUSTOM_SAVE_IMG) = #PB_Checkbox_Checked)
      saveFolder = PathRequester("Select output folder", gImgFolderPath)
      If saveFolder = "" : ProcedureReturn : EndIf
    Else
      saveFolder = gImgFolderPath
    EndIf
    
    DisableGadget(#BTN_IMG_CONVERT, #True) : DisableGadget(#BTN_BROWSE_IMG, #True)
    HideGadget(#BTN_CANCEL_IMG, #False)
    SetGadgetText(#TXT_STATUS_IMG, "Converting 0 of " + Str(fileCount) + " files...")
    
    For i = 0 To gImgFileCount - 1
      If gImgCancelled : Break : EndIf
      
      inputFile = gImgFolderPath + gImgFiles(i)
      baseName = GetFilePart(gImgFiles(i), #PB_FileSystem_NoExtension)
      outputFile = saveFolder + baseName + "." + outExt
      
      ; Skip if input = output
      If LCase(inputFile) = LCase(outputFile)
        outputFile = saveFolder + baseName + "_converted." + outExt
      EndIf
      
      progressPct = Int((i + 1) * 100.0 / fileCount)
      SetGadgetState(#PROG_IMG, progressPct)
      SetGadgetText(#TXT_STATUS_IMG, "Converting " + Str(i + 1) + " of " + Str(fileCount) + "... (" + gImgFiles(i) + ")")
      
      If ConvertSingleImage(inputFile, outputFile, formatIdx, quality)
        successCount + 1
        gImgLastSavePath = outputFile
      Else
        If gImgCancelled = #False
          failCount + 1
          WriteLog("ImgConvert FAIL: " + inputFile)
        EndIf
      EndIf
    Next
    
    If gImgCancelled
      SetGadgetColor(#TXT_STATUS_IMG, #PB_Gadget_FrontColor, RGB(200, 0, 0))
      SetGadgetText(#TXT_STATUS_IMG, "Cancelled! Converted " + Str(successCount) + " of " + Str(fileCount) + " files.")
    Else
      SetGadgetState(#PROG_IMG, 100)
      SetGadgetColor(#TXT_STATUS_IMG, #PB_Gadget_FrontColor, RGB(0, 160, 0))
      Protected resultMsg.s = "By the Great Alzara!  (" + Str(successCount) + " converted"
      If failCount > 0 : resultMsg + ", " + Str(failCount) + " failed" : EndIf
      resultMsg + ")"
      SetGadgetText(#TXT_STATUS_IMG, resultMsg)
      HideGadget(#BTN_OPEN_FOLDER_IMG, #False)
      MessageRequester(#APP_TITLE, "Batch conversion completed!" + #CRLF$ + "Success: " + Str(successCount) + #CRLF$ + "Failed: " + Str(failCount) + #CRLF$ + "Output: " + saveFolder)
    EndIf
  EndIf
  
  DisableGadget(#BTN_IMG_CONVERT, #False) : DisableGadget(#BTN_BROWSE_IMG, #False)
  HideGadget(#BTN_CANCEL_IMG, #True)
EndProcedure

; =====================================================================
; LoadImageInput: called when user browses for file or folder
; =====================================================================
Procedure LoadImageInput()
  Protected mode = GetGadgetState(#COMBO_IMG_MODE)
  Protected path.s, info.s, fileCount
  
  If mode = 0
    ; Single file
    path = OpenFileRequester("Select Image", "", "Images (*.heic;*.heif;*.png;*.webp;*.bmp;*.tiff;*.tif)|*.heic;*.heif;*.png;*.webp;*.bmp;*.tiff;*.tif|All (*.*)|*.*", 0)
    If path = ""  : ProcedureReturn : EndIf
    gImgInputPath = path
    gImgFolderPath = ""
    SetGadgetText(#STR_IMG_INPUT, path)
    info = GetFilePart(path) + "  |  " + FormatFileSize(FileSize(path)) + "  |  " + UCase(GetExtensionPart(path))
    SetGadgetText(#TXT_IMG_INFO, info)
    DisableGadget(#BTN_IMG_CONVERT, #False)
    SetGadgetText(#TXT_STATUS_IMG, "Ready. Click Convert.")
  Else
    ; Folder
    path = PathRequester("Select folder with images", "")
    If path = "" : ProcedureReturn : EndIf
    gImgFolderPath = path
    gImgInputPath = ""
    SetGadgetText(#STR_IMG_INPUT, path)
    fileCount = ScanImageFolder(path)
    info = Str(fileCount) + " supported image(s) found"
    SetGadgetText(#TXT_IMG_INFO, info)
    If fileCount > 0
      DisableGadget(#BTN_IMG_CONVERT, #False)
      SetGadgetText(#TXT_STATUS_IMG, "Ready. " + Str(fileCount) + " file(s) to convert.")
    Else
      DisableGadget(#BTN_IMG_CONVERT, #True)
      SetGadgetText(#TXT_STATUS_IMG, "No supported images found.")
    EndIf
  EndIf
  
  SetGadgetColor(#TXT_STATUS_IMG, #PB_Gadget_FrontColor, RGB(0, 0, 0))
  SetGadgetState(#PROG_IMG, 0)
  HideGadget(#BTN_OPEN_FOLDER_IMG, #True)
EndProcedure

; =====================================================================
; UpdateImgQualityLabel
; =====================================================================
Procedure UpdateImgQualityLabel()
  SetGadgetText(#TXT_IMG_QUALITY_VAL, Str(GetGadgetState(#TRACK_IMG_QUALITY)) + "%")
EndProcedure

; =====================================================================
; OnImgModeChange: when user switches between Single/Folder
; =====================================================================
Procedure OnImgModeChange()
  SetGadgetText(#STR_IMG_INPUT, "")
  SetGadgetText(#TXT_IMG_INFO, "")
  SetGadgetText(#TXT_STATUS_IMG, "Ready. Select input and click Convert.")
  SetGadgetState(#PROG_IMG, 0)
  DisableGadget(#BTN_IMG_CONVERT, #True)
  HideGadget(#BTN_OPEN_FOLDER_IMG, #True)
  gImgInputPath = "" : gImgFolderPath = ""
EndProcedure

; IDE Options = PureBasic 6.20 (Windows - x64)
; CursorPosition = 186
; FirstLine = 138
; Folding = --
; EnableXP
; DPIAware