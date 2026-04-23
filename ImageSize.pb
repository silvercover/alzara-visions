; ======================================================================
; Module : ImageSize.pb
; Version: 1.2b - HEIC two-pass, fixed RunProgram
; ======================================================================

Global gImgSzInputPath.s = ""
Global gImgSzLastSavePath.s = ""
Global gImgSzCancelled = #False
Global gImgSzWidth = 0
Global gImgSzHeight = 0
Global gImgSzFileSize.q = 0
Global gImgSzIsHEIC = #False

Procedure.s GetScaleAlgorithm(algoIdx)
  Select algoIdx
    Case 0 : ProcedureReturn "fast_bilinear"
    Case 1 : ProcedureReturn "bilinear"
    Case 2 : ProcedureReturn "bicubic"
    Case 3 : ProcedureReturn "lanczos"
    Default : ProcedureReturn "lanczos"
  EndSelect
EndProcedure

; =====================================================================
; RunImgBat: run bat file, handle cancel and close, return #True if OK
; =====================================================================
Procedure RunImgBat(batFile.s)
  Protected cmdArgs.s = "/c " + Chr(34) + batFile + Chr(34)
  Protected workDir.s = gTempDir
  Protected proc, ev
  
  proc = RunProgram("cmd.exe", cmdArgs, workDir, #PB_Program_Open | #PB_Program_Hide)
  If proc = 0 : ProcedureReturn #False : EndIf
  
  While ProgramRunning(proc)
    Repeat
      ev = WindowEvent()
      If ev = #PB_Event_Gadget And EventGadget() = #BTN_CANCEL_IMGSZ
        gImgSzCancelled = #True : KillFFmpeg() : KillProgram(proc)
      EndIf
      If ev = #PB_Event_CloseWindow : KillFFmpeg() : KillProgram(proc) : CloseProgram(proc) : End : EndIf
    Until ev = 0
    If gImgSzCancelled : Break : EndIf
    Delay(30)
  Wend
  CloseProgram(proc)
  
  If gImgSzCancelled : ProcedureReturn #False : EndIf
  ProcedureReturn #True
EndProcedure

; =====================================================================
; ProbeImageInfo: reads Tile Grid first (HEIC), then Video
; =====================================================================
Procedure ProbeImageInfo(filePath.s)
  Protected batFile.s = gTempDir + "alzara_imgprobe.bat"
  Protected outFile.s = gTempDir + "alzara_imgprobe_out.txt"
  Protected allOutput.s, pos, k
  
  gImgSzWidth = 0 : gImgSzHeight = 0 : gImgSzIsHEIC = #False
  
  Protected ext.s = LCase(GetExtensionPart(filePath))
  If ext = "heic" Or ext = "heif" : gImgSzIsHEIC = #True : EndIf
  
  If FileSize(outFile) >= 0 : DeleteFile(outFile) : EndIf
  Protected cmd.s = Chr(34) + gFFmpegPath + Chr(34) + " -i " + Chr(34) + filePath + Chr(34) + " 2>" + Chr(34) + outFile + Chr(34)
  If WriteBatFile(batFile, cmd) = "" : ProcedureReturn : EndIf
  RunBatAndWait(batFile) : Delay(100)
  allOutput = ReadEntireFile(outFile)
  WriteLog("ImgProbe output: " + Left(allOutput, 3000))
  
  If FindString(allOutput, "major_brand     : heic") > 0 Or FindString(allOutput, "Tile Grid:") > 0
    gImgSzIsHEIC = #True
  EndIf
  
  ; Priority 1: Tile Grid (HEIC main image)
  pos = FindString(allOutput, "Tile Grid:")
  If pos > 0
    Protected tgLine.s = Mid(allOutput, pos, 500)
    k = 1
    While k <= Len(tgLine) - 3
      Protected c1.s = Mid(tgLine, k, 1)
      If c1 >= "0" And c1 <= "9"
        Protected ts1 = k
        While k <= Len(tgLine) And Mid(tgLine, k, 1) >= "0" And Mid(tgLine, k, 1) <= "9" : k + 1 : Wend
        Protected tn1.s = Mid(tgLine, ts1, k - ts1)
        If k <= Len(tgLine) And Mid(tgLine, k, 1) = "x"
          k + 1
          Protected ts2 = k
          While k <= Len(tgLine) And Mid(tgLine, k, 1) >= "0" And Mid(tgLine, k, 1) <= "9" : k + 1 : Wend
          Protected tn2.s = Mid(tgLine, ts2, k - ts2)
          Protected tw = Val(tn1) : Protected th = Val(tn2)
          If tw >= 8 And tw <= 65536 And th >= 8 And th <= 65536
            Protected tnc.s = Mid(tgLine, k, 1)
            If tnc < "0" Or tnc > "9"
              gImgSzWidth = tw : gImgSzHeight = th
              WriteLog("ImgProbe (TileGrid): " + Str(tw) + "x" + Str(th))
              DeleteFile(batFile) : DeleteFile(outFile)
              ProcedureReturn
            EndIf
          EndIf
        EndIf
      Else : k + 1 : EndIf
    Wend
  EndIf
  
  ; Priority 2: Video line (regular images)
  pos = FindString(allOutput, "Video:")
  If pos > 0
    Protected vLine.s = Mid(allOutput, pos, 500)
    k = 1
    While k <= Len(vLine) - 3
      Protected c2.s = Mid(vLine, k, 1)
      If c2 >= "0" And c2 <= "9"
        Protected vs1 = k
        While k <= Len(vLine) And Mid(vLine, k, 1) >= "0" And Mid(vLine, k, 1) <= "9" : k + 1 : Wend
        Protected vn1.s = Mid(vLine, vs1, k - vs1)
        If k <= Len(vLine) And Mid(vLine, k, 1) = "x"
          k + 1
          Protected vs2 = k
          While k <= Len(vLine) And Mid(vLine, k, 1) >= "0" And Mid(vLine, k, 1) <= "9" : k + 1 : Wend
          Protected vn2.s = Mid(vLine, vs2, k - vs2)
          Protected vw = Val(vn1) : Protected vh = Val(vn2)
          If vw >= 8 And vw <= 65536 And vh >= 8 And vh <= 65536
            Protected vnc.s = Mid(vLine, k, 1)
            If vnc < "0" Or vnc > "9"
              gImgSzWidth = vw : gImgSzHeight = vh
              WriteLog("ImgProbe (Video): " + Str(vw) + "x" + Str(vh))
              Break
            EndIf
          EndIf
        EndIf
      Else : k + 1 : EndIf
    Wend
  EndIf
  
  DeleteFile(batFile) : DeleteFile(outFile)
EndProcedure

Procedure UpdateImgSzPreview()
  If gImgSzWidth > 0 And gImgSzHeight > 0
    Protected pct = GetGadgetState(#TRACK_IMGSZ_SCALE)
    Protected newW = MakeEven(Round(gImgSzWidth * pct / 100.0, #PB_Round_Nearest))
    Protected newH = MakeEven(Round(gImgSzHeight * pct / 100.0, #PB_Round_Nearest))
    If newW < 2 : newW = 2 : EndIf
    If newH < 2 : newH = 2 : EndIf
    SetGadgetText(#TXT_IMGSZ_NEW, "New: " + Str(newW) + " x " + Str(newH) + " (" + Str(pct) + "%)")
    If GetGadgetState(#CHK_IMGSZ_ASPECT) = #PB_Checkbox_Checked
      SetGadgetText(#STR_IMGSZ_W, Str(newW))
      SetGadgetText(#STR_IMGSZ_H, Str(newH))
    EndIf
  EndIf
EndProcedure

Procedure UpdateImgSzFromWidth()
  If gImgSzWidth > 0 And gImgSzHeight > 0
    Protected newW = Val(GetGadgetText(#STR_IMGSZ_W))
    If newW < 2 : newW = 2 : EndIf
    If GetGadgetState(#CHK_IMGSZ_ASPECT) = #PB_Checkbox_Checked
      Protected ratio.d = gImgSzHeight * 1.0 / gImgSzWidth
      Protected newH = MakeEven(Round(newW * ratio, #PB_Round_Nearest))
      If newH < 2 : newH = 2 : EndIf
      SetGadgetText(#STR_IMGSZ_H, Str(newH))
    EndIf
  EndIf
EndProcedure

Procedure UpdateImgSzFromHeight()
  If gImgSzWidth > 0 And gImgSzHeight > 0
    Protected newH = Val(GetGadgetText(#STR_IMGSZ_H))
    If newH < 2 : newH = 2 : EndIf
    If GetGadgetState(#CHK_IMGSZ_ASPECT) = #PB_Checkbox_Checked
      Protected ratio.d = gImgSzWidth * 1.0 / gImgSzHeight
      Protected newW = MakeEven(Round(newH * ratio, #PB_Round_Nearest))
      If newW < 2 : newW = 2 : EndIf
      SetGadgetText(#STR_IMGSZ_W, Str(newW))
    EndIf
  EndIf
EndProcedure

Procedure LoadImgSzInput()
  Protected path.s, info.s
  path = OpenFileRequester("Select Image", "", "Images (*.jpg;*.jpeg;*.png;*.webp;*.bmp;*.tiff;*.tif;*.heic;*.heif)|*.jpg;*.jpeg;*.png;*.webp;*.bmp;*.tiff;*.tif;*.heic;*.heif|All (*.*)|*.*", 0)
  If path = "" : ProcedureReturn : EndIf
  gImgSzInputPath = path
  SetGadgetText(#STR_IMGSZ_INPUT, path)
  SetGadgetColor(#TXT_STATUS_IMGSZ, #PB_Gadget_FrontColor, RGB(0, 0, 0))
  SetGadgetState(#PROG_IMGSZ, 0)
  HideGadget(#BTN_OPEN_FOLDER_IMGSZ, #True)
  SetGadgetText(#TXT_STATUS_IMGSZ, "Analyzing...")
  SetGadgetText(#TXT_IMGSZ_INFO, "Analyzing...")
  Repeat : Until WindowEvent() = 0
  gImgSzFileSize = FileSize(path)
  ProbeImageInfo(path)
  info = FormatFileSize(gImgSzFileSize)
  If gImgSzWidth > 0 And gImgSzHeight > 0
    info + "  |  " + Str(gImgSzWidth) + " x " + Str(gImgSzHeight)
  Else : info + "  |  Resolution: Unknown" : EndIf
  info + "  |  " + UCase(GetExtensionPart(path))
  If gImgSzIsHEIC : info + " (HEIC)" : EndIf
  SetGadgetText(#TXT_IMGSZ_INFO, info)
  SetGadgetText(#TXT_IMGSZ_ORIG, "Original: " + Str(gImgSzWidth) + " x " + Str(gImgSzHeight))
  SetGadgetState(#TRACK_IMGSZ_SCALE, 50)
  SetGadgetText(#STR_IMGSZ_W, Str(gImgSzWidth))
  SetGadgetText(#STR_IMGSZ_H, Str(gImgSzHeight))
  UpdateImgSzPreview()
  DisableGadget(#BTN_IMGSZ_RESIZE, #False)
  SetGadgetText(#TXT_STATUS_IMGSZ, "Ready. Set options and click Resize.")
EndProcedure

; =====================================================================
; DoImageResize: TWO-PASS for HEIC, single pass for others
; =====================================================================
Procedure DoImageResize()
  Protected savePath.s, args.s
  Protected newW, newH, quality, algoIdx
  Protected algo.s, ext.s
  Protected useSlider, pct
  Protected newSize.q, savedInfo.s, savedPct.d
  Protected batFile.s, errFile.s, errContent.s, batCmd.s
  Protected tempJpg.s, inputForResize.s
  
  If gImgSzInputPath = ""
    MessageRequester("Alzara Vision", "Please select an input image.")
    ProcedureReturn
  EndIf
  
  useSlider = Bool(GetGadgetState(#CHK_IMGSZ_SLIDER) = #PB_Checkbox_Checked)
  If useSlider
    pct = GetGadgetState(#TRACK_IMGSZ_SCALE)
    newW = MakeEven(Round(gImgSzWidth * pct / 100.0, #PB_Round_Nearest))
    newH = MakeEven(Round(gImgSzHeight * pct / 100.0, #PB_Round_Nearest))
  Else
    newW = Val(GetGadgetText(#STR_IMGSZ_W))
    newH = Val(GetGadgetText(#STR_IMGSZ_H))
  EndIf
  If newW < 2 : newW = 2 : EndIf
  If newH < 2 : newH = 2 : EndIf
  
  If newW = gImgSzWidth And newH = gImgSzHeight
    If MessageRequester("Alzara Vision", "Dimensions are the same as original. Continue anyway?", #PB_MessageRequester_YesNo) = #PB_MessageRequester_No
      ProcedureReturn
    EndIf
  EndIf
  
  quality = GetGadgetState(#TRACK_IMGSZ_QUALITY)
  algoIdx = GetGadgetState(#COMBO_IMGSZ_ALGO)
  algo = GetScaleAlgorithm(algoIdx)
  
  ext = LCase(GetExtensionPart(gImgSzInputPath))
  If ext = "heic" Or ext = "heif" : ext = "jpg" : EndIf
  If ext = "tiff" Or ext = "tif" : ext = "png" : EndIf
  If ext = "bmp" : ext = "png" : EndIf
  
  Protected baseName.s = GetFilePart(gImgSzInputPath, #PB_FileSystem_NoExtension)
  Protected baseFolder.s = GetPathPart(gImgSzInputPath)
  
  If Bool(GetGadgetState(#CHK_CUSTOM_SAVE_IMGSZ) = #PB_Checkbox_Checked)
    savePath = SaveFileRequester("Save Resized Image As...", baseFolder + baseName + "_resized." + ext, UCase(ext) + " (*." + ext + ")|*." + ext, 0)
    If savePath = "" : ProcedureReturn : EndIf
  Else
    savePath = baseFolder + baseName + "_resized." + ext
  EndIf
  
  SetGadgetColor(#TXT_STATUS_IMGSZ, #PB_Gadget_FrontColor, RGB(0, 0, 0))
  SetGadgetState(#PROG_IMGSZ, 0)
  HideGadget(#BTN_OPEN_FOLDER_IMGSZ, #True)
  gImgSzCancelled = #False : gImgSzLastSavePath = ""
  
  DisableGadget(#BTN_IMGSZ_RESIZE, #True) : DisableGadget(#BTN_BROWSE_IMGSZ, #True)
  HideGadget(#BTN_CANCEL_IMGSZ, #False)
  
  batFile = gTempDir + "alzara_imgsz.bat"
  errFile = gTempDir + "alzara_imgsz_err.txt"
  tempJpg = gTempDir + "alzara_heic_temp.jpg"
  inputForResize = gImgSzInputPath
  
  ; =============================================================
  ; STEP 1: If HEIC, decode to temp full-size JPG first
  ; =============================================================
  If gImgSzIsHEIC
    WriteLog("HEIC detected - two-pass method")
    SetGadgetText(#TXT_STATUS_IMGSZ, "Step 1/2: Decoding HEIC...")
    SetGadgetState(#PROG_IMGSZ, 20)
    
    If FileSize(tempJpg) >= 0 : DeleteFile(tempJpg) : EndIf
    If FileSize(errFile) >= 0 : DeleteFile(errFile) : EndIf
    
    args = "-y -i " + Chr(34) + gImgSzInputPath + Chr(34) + " -update 1 -frames:v 1 -q:v 1 " + Chr(34) + tempJpg + Chr(34)
    batCmd = Chr(34) + gFFmpegPath + Chr(34) + " " + args + " 2>" + Chr(34) + errFile + Chr(34)
    WriteLog("HEIC Step1: " + batCmd)
    
    If WriteBatFile(batFile, batCmd) = ""
      MessageRequester("Error", "Cannot create batch file.")
      DisableGadget(#BTN_IMGSZ_RESIZE, #False) : DisableGadget(#BTN_BROWSE_IMGSZ, #False)
      HideGadget(#BTN_CANCEL_IMGSZ, #True) : ProcedureReturn
    EndIf
    
    If RunImgBat(batFile) = #False
      If gImgSzCancelled
        SetGadgetColor(#TXT_STATUS_IMGSZ, #PB_Gadget_FrontColor, RGB(200, 0, 0))
        SetGadgetText(#TXT_STATUS_IMGSZ, "Cancelled!")
      Else
        SetGadgetColor(#TXT_STATUS_IMGSZ, #PB_Gadget_FrontColor, RGB(200, 0, 0))
        SetGadgetText(#TXT_STATUS_IMGSZ, "Error running ffmpeg!")
      EndIf
      SetGadgetState(#PROG_IMGSZ, 0)
      DisableGadget(#BTN_IMGSZ_RESIZE, #False) : DisableGadget(#BTN_BROWSE_IMGSZ, #False)
      HideGadget(#BTN_CANCEL_IMGSZ, #True)
      DeleteFile(batFile) : DeleteFile(errFile) : ProcedureReturn
    EndIf
    
    errContent = ReadEntireFile(errFile)
    If Len(errContent) > 0 : WriteLog("HEIC Step1 stderr: " + Left(errContent, 500)) : EndIf
    
    If FileSize(tempJpg) <= 0
      SetGadgetColor(#TXT_STATUS_IMGSZ, #PB_Gadget_FrontColor, RGB(200, 0, 0))
      SetGadgetText(#TXT_STATUS_IMGSZ, "Error decoding HEIC!")
      SetGadgetState(#PROG_IMGSZ, 0)
      WriteLog("HEIC Step1 FAILED")
      DisableGadget(#BTN_IMGSZ_RESIZE, #False) : DisableGadget(#BTN_BROWSE_IMGSZ, #False)
      HideGadget(#BTN_CANCEL_IMGSZ, #True)
      DeleteFile(batFile) : DeleteFile(errFile) : ProcedureReturn
    EndIf
    
    WriteLog("HEIC Step1 OK: " + FormatFileSize(FileSize(tempJpg)))
    inputForResize = tempJpg
  EndIf
  
  ; =============================================================
  ; STEP 2: Resize
  ; =============================================================
  If gImgSzIsHEIC
    SetGadgetText(#TXT_STATUS_IMGSZ, "Step 2/2: Resizing...")
  Else
    SetGadgetText(#TXT_STATUS_IMGSZ, "Resizing...")
  EndIf
  SetGadgetState(#PROG_IMGSZ, 60)
  If FileSize(errFile) >= 0 : DeleteFile(errFile) : EndIf
  
  args = "-y -i " + Chr(34) + inputForResize + Chr(34)
  args + " -vf " + Chr(34) + "scale=" + Str(newW) + ":" + Str(newH) + ":flags=" + algo + Chr(34)
  args + " -update 1 -frames:v 1"
  
  Select ext
    Case "jpg", "jpeg"
      Protected qv = 2 + Round((100 - quality) * 29.0 / 99.0, #PB_Round_Nearest)
      If qv < 2 : qv = 2 : EndIf
      If qv > 31 : qv = 31 : EndIf
      args + " -q:v " + Str(qv)
    Case "webp"
      args + " -quality " + Str(quality)
    Case "png"
      args + " -compression_level 6"
  EndSelect
  
  args + " " + Chr(34) + savePath + Chr(34)
  batCmd = Chr(34) + gFFmpegPath + Chr(34) + " " + args + " 2>" + Chr(34) + errFile + Chr(34)
  WriteLog("Step2: " + batCmd)
  
  If WriteBatFile(batFile, batCmd) = ""
    MessageRequester("Error", "Cannot create batch file.")
    If gImgSzIsHEIC And FileSize(tempJpg) >= 0 : DeleteFile(tempJpg) : EndIf
    DisableGadget(#BTN_IMGSZ_RESIZE, #False) : DisableGadget(#BTN_BROWSE_IMGSZ, #False)
    HideGadget(#BTN_CANCEL_IMGSZ, #True) : ProcedureReturn
  EndIf
  
  RunImgBat(batFile)
  
  errContent = ReadEntireFile(errFile)
  If Len(errContent) > 0 : WriteLog("Step2 stderr: " + Left(errContent, 500)) : EndIf
  If gImgSzIsHEIC And FileSize(tempJpg) >= 0 : DeleteFile(tempJpg) : EndIf
  
  ; =============================================================
  ; Result
  ; =============================================================
  If gImgSzCancelled
    SetGadgetColor(#TXT_STATUS_IMGSZ, #PB_Gadget_FrontColor, RGB(200, 0, 0))
    SetGadgetText(#TXT_STATUS_IMGSZ, "Operation Cancelled!")
    SetGadgetState(#PROG_IMGSZ, 0)
    If FileSize(savePath) >= 0 : DeleteFile(savePath) : EndIf
  ElseIf FileSize(savePath) > 0
    gImgSzLastSavePath = savePath
    SetGadgetState(#PROG_IMGSZ, 100)
    SetGadgetColor(#TXT_STATUS_IMGSZ, #PB_Gadget_FrontColor, RGB(0, 160, 0))
    newSize = FileSize(savePath)
    savedInfo = FormatFileSize(newSize) + "  |  " + Str(newW) + "x" + Str(newH)
    If gImgSzFileSize > 0 And newSize > 0 And newSize < gImgSzFileSize
      savedPct = (1.0 - (newSize * 1.0 / gImgSzFileSize)) * 100.0
      savedInfo + "  |  Saved " + StrD(savedPct, 1) + "%"
    EndIf
    SetGadgetText(#TXT_STATUS_IMGSZ, "By the Great Alzara!  (" + savedInfo + ")")
    HideGadget(#BTN_OPEN_FOLDER_IMGSZ, #False)
    WriteLog("Done. " + Str(gImgSzWidth) + "x" + Str(gImgSzHeight) + " -> " + Str(newW) + "x" + Str(newH))
    MessageRequester(#APP_TITLE, "Image resized!" + #CRLF$ + "Original: " + Str(gImgSzWidth) + "x" + Str(gImgSzHeight) + " (" + FormatFileSize(gImgSzFileSize) + ")" + #CRLF$ + "New: " + Str(newW) + "x" + Str(newH) + " (" + FormatFileSize(newSize) + ")" + #CRLF$ + "Saved: " + savePath)
  Else
    SetGadgetColor(#TXT_STATUS_IMGSZ, #PB_Gadget_FrontColor, RGB(200, 0, 0))
    SetGadgetText(#TXT_STATUS_IMGSZ, "Error! Check log.")
    SetGadgetState(#PROG_IMGSZ, 0)
    WriteLog("FAILED. stderr: " + errContent)
  EndIf
  
  DisableGadget(#BTN_IMGSZ_RESIZE, #False) : DisableGadget(#BTN_BROWSE_IMGSZ, #False)
  HideGadget(#BTN_CANCEL_IMGSZ, #True)
  DeleteFile(batFile) : DeleteFile(errFile)
EndProcedure

; IDE Options = PureBasic 6.20 (Windows - x64)
; CursorPosition = 406
; FirstLine = 354
; Folding = --
; EnableXP
; DPIAware
; Executable = Alzara Visions.exe