; ======================================================================
; Project : Alzara Vision
; Version : 1.4.1
; Author  : Hamed Takmil (aka silvercover)
; Language: PureBasic 5.x / 6.x (Windows)
; Backend : ffmpeg.exe (place next to this executable)
; ======================================================================

EnableExplicit

#WIN_MAIN = 0
#APP_VERSION = "1.4.1"
#APP_NAME    = "Alzara Vision"
#APP_TITLE   = #APP_NAME + " " + #APP_VERSION
#APP_AUTHOR  = "Hamed Takmil (aka silvercover)"


Enumeration Gadgets
  #PANEL_TABS
  #STR_FOLDER
  #BTN_BROWSE
  #LIST_VIDEOS
  #BTN_MOVE_UP
  #BTN_MOVE_DOWN
  #CHK_CUSTOM_SAVE
  #BTN_MERGE
  #BTN_CANCEL_MERGE
  #BTN_OPEN_FOLDER_MERGE
  #PROG_MERGE
  #TXT_STATUS_MERGE
  #STR_INPUT_FILE
  #BTN_BROWSE_FILE
  #TXT_FILE_INFO
  #FRAME_SIZE
  #CHK_REDUCE_SIZE
  #TXT_SIZE_LABEL
  #TRACK_SIZE
  #TXT_SIZE_VAL
  #FRAME_DIM
  #CHK_REDUCE_DIM
  #TXT_DIM_LABEL
  #TRACK_DIM
  #TXT_DIM_ORIG
  #TXT_DIM_NEW
  #CHK_CUSTOM_SAVE_R
  #BTN_REDUCE
  #BTN_CANCEL_REDUCE
  #BTN_OPEN_FOLDER_REDUCE
  #BTN_PLAY_VIDEO
  #PROG_REDUCE
  #TXT_STATUS_REDUCE
  #STR_AUDIO_INPUT
  #BTN_BROWSE_AUDIO
  #TXT_AUDIO_INFO
  #COMBO_FORMAT
  #TXT_FORMAT_LABEL
  #CHK_CUSTOM_SAVE_A
  #BTN_EXTRACT
  #BTN_CANCEL_EXTRACT
  #BTN_OPEN_FOLDER_AUDIO
  #BTN_PLAY_AUDIO
  #PROG_AUDIO
  #TXT_STATUS_AUDIO
  #CHK_REMOVE_AUDIO
  #CHK_NOISE_REDUCE
  ; --- Image Convert Tab ---
  #COMBO_IMG_MODE
  #STR_IMG_INPUT
  #BTN_BROWSE_IMG
  #TXT_IMG_INFO
  #COMBO_IMG_FORMAT
  #TXT_IMG_FORMAT_LABEL
  #TXT_IMG_QUALITY_LABEL
  #TRACK_IMG_QUALITY
  #TXT_IMG_QUALITY_VAL
  #CHK_CUSTOM_SAVE_IMG
  #BTN_IMG_CONVERT
  #BTN_CANCEL_IMG
  #BTN_OPEN_FOLDER_IMG
  #PROG_IMG
  #TXT_STATUS_IMG  
  ; --- Image Size Tab ---
  #STR_IMGSZ_INPUT
  #BTN_BROWSE_IMGSZ
  #TXT_IMGSZ_INFO
  #FRAME_IMGSZ_SLIDER
  #CHK_IMGSZ_SLIDER
  #TXT_IMGSZ_SCALE_LABEL
  #TRACK_IMGSZ_SCALE
  #TXT_IMGSZ_ORIG
  #TXT_IMGSZ_NEW
  #FRAME_IMGSZ_MANUAL
  #TXT_IMGSZ_W_LABEL
  #STR_IMGSZ_W
  #TXT_IMGSZ_X
  #STR_IMGSZ_H
  #CHK_IMGSZ_ASPECT
  #TXT_IMGSZ_ALGO_LABEL
  #COMBO_IMGSZ_ALGO
  #TXT_IMGSZ_QUALITY_LABEL
  #TRACK_IMGSZ_QUALITY
  #TXT_IMGSZ_QUALITY_VAL
  #CHK_CUSTOM_SAVE_IMGSZ
  #BTN_IMGSZ_RESIZE
  #BTN_CANCEL_IMGSZ
  #BTN_OPEN_FOLDER_IMGSZ
  #PROG_IMGSZ
  #TXT_STATUS_IMGSZ  
  #BTN_REMOVE_ITEM
  #BTN_RELOAD_LIST  
  #BTN_SORT_AZ
  
EndEnumeration

Enumeration Menus
  #MENU_OPEN_LOG
  #MENU_ABOUT
EndEnumeration

Global gLastSavePathReduce.s = ""
Global gLastSavePathAudio.s = ""
Global gInputFile.s = ""
Global gInputWidth = 0
Global gInputHeight = 0
Global gInputDuration.d = 0.0
Global gInputFileSize.q = 0
Global gInputCodec.s = ""
Global gInputBitrate = 0
Global gInputFPS.s = ""
Global gAudioInputFile.s = ""
Global gAudioInputDuration.d = 0.0
Global gAudioInputFileSize.q = 0
Global gAudioInputAudioCodec.s = ""
Global gAudioInputAudioBR = 0
Global gCancelledReduce = #False
Global gCancelledExtract = #False
Global gFFmpegPath.s = ""
Global gAppDir.s = ""
Global gLogFile.s = ""
Global gTempDir.s = ""

Procedure InitPaths()
  gAppDir = GetPathPart(ProgramFilename())
  gFFmpegPath = gAppDir + "ffmpeg.exe"
  gLogFile = gAppDir + "alzara_debug.log"
  gTempDir = GetTemporaryDirectory()
EndProcedure

Procedure WriteLog(msg.s)
  Protected fid = OpenFile(#PB_Any, gLogFile, #PB_File_Append)
  If fid = 0 : fid = CreateFile(#PB_Any, gLogFile) : EndIf
  If fid : WriteStringN(fid, FormatDate("%yyyy-%mm-%dd %hh:%ii:%ss", Date()) + "  " + msg) : CloseFile(fid) : EndIf
EndProcedure

Procedure.s WriteBatFile(batPath.s, command.s)
  Protected fid
  If FileSize(batPath) >= 0 : DeleteFile(batPath) : EndIf
  fid = CreateFile(#PB_Any, batPath)
  If fid
    WriteByte(fid, $EF) : WriteByte(fid, $BB) : WriteByte(fid, $BF)
    WriteStringN(fid, "@echo off", #PB_UTF8)
    WriteStringN(fid, "chcp 65001 >nul", #PB_UTF8)
    WriteStringN(fid, command, #PB_UTF8)
    WriteStringN(fid, "exit /b", #PB_UTF8)
    CloseFile(fid) : ProcedureReturn batPath
  EndIf
  ProcedureReturn ""
EndProcedure

Procedure RunBatAndWait(batFile.s)
  Protected proc = RunProgram("cmd.exe", "/c " + Chr(34) + batFile + Chr(34), gTempDir, #PB_Program_Open | #PB_Program_Hide)
  If proc
    While ProgramRunning(proc)
      Protected ev = WindowEvent()
      If ev = #PB_Event_CloseWindow : KillProgram(proc) : CloseProgram(proc) : End : EndIf
      Delay(20)
    Wend
    CloseProgram(proc)
  EndIf
EndProcedure

Procedure.s ReadEntireFile(path.s)
  Protected result.s = "", fid
  fid = ReadFile(#PB_Any, path)
  If fid
    While Not Eof(fid) : result + ReadString(fid) + Chr(10) : Wend
    CloseFile(fid)
  EndIf
  ProcedureReturn result
EndProcedure

Procedure KillFFmpeg()
  RunProgram("taskkill", "/f /im ffmpeg.exe", "", #PB_Program_Open | #PB_Program_Hide | #PB_Program_Wait)
  Delay(100)
EndProcedure

Procedure OpenFolder(path.s)
  If path <> "" : RunProgram("explorer.exe", GetPathPart(path), "") : EndIf
EndProcedure

Procedure.s FormatFileSize(bytes.q)
  If bytes >= 1073741824 : ProcedureReturn StrD(bytes / 1073741824.0, 2) + " GB"
  ElseIf bytes >= 1048576 : ProcedureReturn StrD(bytes / 1048576.0, 2) + " MB"
  ElseIf bytes >= 1024 : ProcedureReturn StrD(bytes / 1024.0, 2) + " KB"
  Else : ProcedureReturn Str(bytes) + " Bytes" : EndIf
EndProcedure

Procedure MakeEven(val)
  If val % 2 <> 0 : val + 1 : EndIf
  If val < 2 : val = 2 : EndIf
  ProcedureReturn val
EndProcedure

Procedure CRFFromPercent(percent)
  Protected crf.d = 45.0 - (percent - 20.0) * 25.0 / 80.0
  ProcedureReturn Round(crf, #PB_Round_Nearest)
EndProcedure

Procedure.s GetFFmpegVersion()
  Protected batFile.s = gTempDir + "alzara_ver.bat"
  Protected outFile.s = gTempDir + "alzara_ver_out.txt"
  Protected result.s = "Unknown", allOutput.s, pos, endPos
  If FileSize(outFile) >= 0 : DeleteFile(outFile) : EndIf
  Protected cmd.s = Chr(34) + gFFmpegPath + Chr(34) + " -version >" + Chr(34) + outFile + Chr(34) + " 2>&1"
  If WriteBatFile(batFile, cmd) <> "" : RunBatAndWait(batFile) : Delay(100) : EndIf
  allOutput = ReadEntireFile(outFile)
  pos = FindString(allOutput, "ffmpeg version ")
  If pos > 0
    Protected verStart = pos + 15
    endPos = FindString(allOutput, " ", verStart)
    If endPos > verStart : result = Mid(allOutput, verStart, endPos - verStart) : EndIf
  EndIf
  DeleteFile(batFile) : DeleteFile(outFile)
  ProcedureReturn result
EndProcedure

Procedure ShowAbout()
  Protected ver.s = GetFFmpegVersion()
  Protected msg.s = #APP_TITLE + #CRLF$
  msg + "Created by " + #APP_AUTHOR + #CRLF$ + #CRLF$
  msg + "This software is provided 'AS IS', without warranty of any kind," + #CRLF$
  msg + "express or implied. No guarantee of fitness for any purpose is" + #CRLF$
  msg + "provided. Use at your own risk." + #CRLF$
  msg + "This software is FREE for personal and commercial use." + #CRLF$ + #CRLF$
  msg + "--- Third-Party Credits ---" + #CRLF$
  msg + "This application uses FFmpeg for all media processing." + #CRLF$
  msg + "FFmpeg version: " + ver + #CRLF$
  msg + "FFmpeg is a trademark of Fabrice Bellard, originator of the" + #CRLF$
  msg + "FFmpeg project. Licensed under the GNU General Public License." + #CRLF$
  msg + "https://ffmpeg.org" + #CRLF$ + #CRLF$
  msg + "Image conversion powered by FFmpeg's image processing capabilities." + #CRLF$
  msg + "Supported formats: HEIC, HEIF, PNG, WEBP, BMP, TIFF." + #CRLF$ + #CRLF$
  msg + "Special thanks to the FFmpeg team and all contributors for" + #CRLF$
  msg + "making such an incredible open-source tool freely available."
  MessageRequester("About " + #APP_NAME, msg)
EndProcedure

; =====================================================================
; ProbeVideoInfo
; =====================================================================
Procedure ProbeVideoInfo(filePath.s)
  Protected batFile.s = gTempDir + "alzara_probe.bat"
  Protected outFile.s = gTempDir + "alzara_probe_out.txt"
  Protected allOutput.s, pos, k
  gInputWidth = 0 : gInputHeight = 0 : gInputDuration = 0.0
  gInputCodec = "" : gInputBitrate = 0 : gInputFPS = ""
  If FileSize(outFile) >= 0 : DeleteFile(outFile) : EndIf
  Protected cmd.s = Chr(34) + gFFmpegPath + Chr(34) + " -i " + Chr(34) + filePath + Chr(34) + " 2>" + Chr(34) + outFile + Chr(34)
  If WriteBatFile(batFile, cmd) = "" : ProcedureReturn : EndIf
  RunBatAndWait(batFile) : Delay(100)
  allOutput = ReadEntireFile(outFile)
  pos = FindString(allOutput, "Duration:")
  If pos > 0
    Protected durStr.s = Mid(allOutput, pos + 10, 11)
    gInputDuration = ValD(Mid(durStr, 1, 2)) * 3600.0 + ValD(Mid(durStr, 4, 2)) * 60.0 + ValD(Mid(durStr, 7, 5))
  EndIf
  pos = FindString(allOutput, "Video:")
  If pos > 0
    Protected videoLine.s = Mid(allOutput, pos, 400)
    Protected codecStart = 7, codecEnd = FindString(videoLine, " ", codecStart)
    If codecEnd > codecStart : gInputCodec = ReplaceString(Trim(Left(Mid(videoLine, codecStart, codecEnd - codecStart), 20)), ",", "") : EndIf
    Protected brVidPos = FindString(videoLine, "kb/s")
    If brVidPos > 0
      Protected numEnd = brVidPos - 2, numStart = numEnd
      While numStart > 0 And Mid(videoLine, numStart, 1) >= "0" And Mid(videoLine, numStart, 1) <= "9" : numStart - 1 : Wend
      numStart + 1
      If numEnd >= numStart : gInputBitrate = Val(Mid(videoLine, numStart, numEnd - numStart + 1)) : EndIf
    EndIf
    Protected fpsPos = FindString(videoLine, " fps")
    If fpsPos > 0
      Protected fpsEnd2 = fpsPos - 1, fpsStart = fpsEnd2
      While fpsStart > 0 And (Mid(videoLine, fpsStart, 1) >= "0" And Mid(videoLine, fpsStart, 1) <= "9" Or Mid(videoLine, fpsStart, 1) = ".")
        fpsStart - 1
      Wend
      fpsStart + 1
      If fpsEnd2 >= fpsStart : gInputFPS = Mid(videoLine, fpsStart, fpsEnd2 - fpsStart + 1) : EndIf
    EndIf
    k = 1
    While k <= Len(videoLine) - 3
      Protected c.s = Mid(videoLine, k, 1)
      If c >= "0" And c <= "9"
        Protected s1 = k
        While k <= Len(videoLine) And Mid(videoLine, k, 1) >= "0" And Mid(videoLine, k, 1) <= "9" : k + 1 : Wend
        Protected n1.s = Mid(videoLine, s1, k - s1)
        If k <= Len(videoLine) And Mid(videoLine, k, 1) = "x"
          k + 1
          Protected s2 = k
          While k <= Len(videoLine) And Mid(videoLine, k, 1) >= "0" And Mid(videoLine, k, 1) <= "9" : k + 1 : Wend
          Protected n2.s = Mid(videoLine, s2, k - s2)
          Protected w = Val(n1) : Protected h = Val(n2)
          If w >= 64 And w <= 15360 And h >= 64 And h <= 8640
            Protected nc.s = Mid(videoLine, k, 1)
            If nc < "0" Or nc > "9" : gInputWidth = w : gInputHeight = h : Break : EndIf
          EndIf
        EndIf
      Else : k + 1 : EndIf
    Wend
  EndIf
  DeleteFile(batFile) : DeleteFile(outFile)
EndProcedure

; =====================================================================
; ProbeAudioInfo
; =====================================================================
Procedure ProbeAudioInfo(filePath.s)
  Protected batFile.s = gTempDir + "alzara_aprobe.bat"
  Protected outFile.s = gTempDir + "alzara_aprobe_out.txt"
  Protected allOutput.s, pos
  gAudioInputDuration = 0.0 : gAudioInputAudioCodec = "" : gAudioInputAudioBR = 0
  If FileSize(outFile) >= 0 : DeleteFile(outFile) : EndIf
  Protected cmd.s = Chr(34) + gFFmpegPath + Chr(34) + " -i " + Chr(34) + filePath + Chr(34) + " 2>" + Chr(34) + outFile + Chr(34)
  If WriteBatFile(batFile, cmd) = "" : ProcedureReturn : EndIf
  RunBatAndWait(batFile) : Delay(100)
  allOutput = ReadEntireFile(outFile)
  pos = FindString(allOutput, "Duration:")
  If pos > 0
    Protected durStr.s = Mid(allOutput, pos + 10, 11)
    gAudioInputDuration = ValD(Mid(durStr, 1, 2)) * 3600.0 + ValD(Mid(durStr, 4, 2)) * 60.0 + ValD(Mid(durStr, 7, 5))
  EndIf
  pos = FindString(allOutput, "Audio:")
  If pos > 0
    Protected audioLine.s = Mid(allOutput, pos, 300)
    Protected aStart = 7, aEnd = FindString(audioLine, " ", aStart)
    If aEnd > aStart : gAudioInputAudioCodec = ReplaceString(Trim(Left(Mid(audioLine, aStart, aEnd - aStart), 20)), ",", "") : EndIf
    Protected abPos = FindString(audioLine, "kb/s")
    If abPos > 0
      Protected anEnd = abPos - 2, anStart = anEnd
      While anStart > 0 And Mid(audioLine, anStart, 1) >= "0" And Mid(audioLine, anStart, 1) <= "9" : anStart - 1 : Wend
      anStart + 1
      If anEnd >= anStart : gAudioInputAudioBR = Val(Mid(audioLine, anStart, anEnd - anStart + 1)) : EndIf
    EndIf
  EndIf
  DeleteFile(batFile) : DeleteFile(outFile)
EndProcedure

Procedure UpdateDimPreview()
  If gInputWidth > 0 And gInputHeight > 0
    Protected pct = GetGadgetState(#TRACK_DIM)
    Protected newW = MakeEven(Round(gInputWidth * pct / 100.0, #PB_Round_Nearest))
    Protected newH = MakeEven(Round(gInputHeight * pct / 100.0, #PB_Round_Nearest))
    SetGadgetText(#TXT_DIM_NEW, "New: " + Str(newW) + " x " + Str(newH) + " (" + Str(pct) + "%)")
  EndIf
EndProcedure

Procedure UpdateSizePreview()
  SetGadgetText(#TXT_SIZE_VAL, Str(GetGadgetState(#TRACK_SIZE)) + "% (Approximate)")
EndProcedure

Procedure LoadInputFile(filePath.s)
  gInputFile = filePath
  SetGadgetText(#STR_INPUT_FILE, filePath)
  SetGadgetColor(#TXT_STATUS_REDUCE, #PB_Gadget_FrontColor, RGB(0, 0, 0))
  SetGadgetState(#PROG_REDUCE, 0)
  HideGadget(#BTN_OPEN_FOLDER_REDUCE, #True) : HideGadget(#BTN_PLAY_VIDEO, #True)
  SetGadgetText(#TXT_STATUS_REDUCE, "Analyzing...") : SetGadgetText(#TXT_FILE_INFO, "Analyzing...")
  Repeat : Until WindowEvent() = 0
  gInputFileSize = FileSize(filePath) : ProbeVideoInfo(filePath)
  Protected info.s = FormatFileSize(gInputFileSize)
  If gInputCodec <> "" : info + "  |  " + UCase(gInputCodec) : EndIf
  If gInputBitrate > 0 : info + " @ " + Str(gInputBitrate) + " kb/s" : EndIf
  If gInputWidth > 0 And gInputHeight > 0 : info + "  |  " + Str(gInputWidth) + "x" + Str(gInputHeight) : EndIf
  If gInputFPS <> "" : info + " @ " + gInputFPS + " fps" : EndIf
  If gInputDuration > 0.0 : info + "  |  " + Str(Int(gInputDuration / 60)) + "m " + Str(Int(gInputDuration) % 60) + "s" : EndIf
  SetGadgetText(#TXT_FILE_INFO, info)
  SetGadgetText(#TXT_DIM_ORIG, "Original: " + Str(gInputWidth) + " x " + Str(gInputHeight))
  UpdateDimPreview() : UpdateSizePreview()
  DisableGadget(#BTN_REDUCE, #False)
  SetGadgetText(#TXT_STATUS_REDUCE, "Ready. Enable options and click Reduce.")
EndProcedure

Procedure LoadAudioInputFile(filePath.s)
  gAudioInputFile = filePath
  SetGadgetText(#STR_AUDIO_INPUT, filePath)
  SetGadgetColor(#TXT_STATUS_AUDIO, #PB_Gadget_FrontColor, RGB(0, 0, 0))
  SetGadgetState(#PROG_AUDIO, 0)
  HideGadget(#BTN_OPEN_FOLDER_AUDIO, #True) : HideGadget(#BTN_PLAY_AUDIO, #True)
  SetGadgetText(#TXT_STATUS_AUDIO, "Analyzing...") : SetGadgetText(#TXT_AUDIO_INFO, "Analyzing...")
  Repeat : Until WindowEvent() = 0
  gAudioInputFileSize = FileSize(filePath) : ProbeAudioInfo(filePath)
  Protected info.s = FormatFileSize(gAudioInputFileSize)
  If gAudioInputAudioCodec <> "" : info + "  |  Audio: " + UCase(gAudioInputAudioCodec) : EndIf
  If gAudioInputAudioBR > 0 : info + " @ " + Str(gAudioInputAudioBR) + " kb/s" : EndIf
  If gAudioInputDuration > 0.0 : info + "  |  " + Str(Int(gAudioInputDuration / 60)) + "m " + Str(Int(gAudioInputDuration) % 60) + "s" : EndIf
  SetGadgetText(#TXT_AUDIO_INFO, info)
  DisableGadget(#BTN_EXTRACT, #False)
  SetGadgetText(#TXT_STATUS_AUDIO, "Ready. Choose format and click Extract.")
EndProcedure

; =====================================================================
; DoReduce - with Remove Audio and Noise Reduction support
; =====================================================================
Procedure DoReduce()
  Protected savePath.s, useSize, useDim
  Protected baseName.s, baseFolder.s
  Protected args.s, pctDim, newW, newH, crf
  Protected proc, ev, line.s
  Protected currentTime.d, progressPct
  Protected timeUs.d, timeDisp.s
  Protected newSize.q, origSize.q, savedInfo.s
  Protected savedPct.d, biggerPct.d
  Protected targetVideoBR, targetAudioBR, sizePct
  Protected dimScale.d, origAudioBR, overallBR
  Protected removeAudio, denoiseAudio
  
  useSize = Bool(GetGadgetState(#CHK_REDUCE_SIZE) = #PB_Checkbox_Checked)
  useDim  = Bool(GetGadgetState(#CHK_REDUCE_DIM)  = #PB_Checkbox_Checked)
  removeAudio = Bool(GetGadgetState(#CHK_REMOVE_AUDIO) = #PB_Checkbox_Checked)
  denoiseAudio = Bool(GetGadgetState(#CHK_NOISE_REDUCE) = #PB_Checkbox_Checked)
  
  If useSize = #False And useDim = #False And removeAudio = #False And denoiseAudio = #False
    MessageRequester("Alzara Vision", "Please enable at least one option.")
    ProcedureReturn
  EndIf
  
  SetGadgetColor(#TXT_STATUS_REDUCE, #PB_Gadget_FrontColor, RGB(0, 0, 0))
  SetGadgetState(#PROG_REDUCE, 0)
  HideGadget(#BTN_OPEN_FOLDER_REDUCE, #True) : HideGadget(#BTN_PLAY_VIDEO, #True)
  gCancelledReduce = #False : gLastSavePathReduce = ""
  
  baseName = GetFilePart(gInputFile, #PB_FileSystem_NoExtension)
  baseFolder = GetPathPart(gInputFile)
  
  If Bool(GetGadgetState(#CHK_CUSTOM_SAVE_R) = #PB_Checkbox_Checked)
    savePath = SaveFileRequester("Save Reduced Video As...", baseFolder + baseName + "_reduced.mp4", "MP4 (*.mp4)|*.mp4", 0)
    If savePath = "" : ProcedureReturn : EndIf
  Else
    savePath = baseFolder + baseName + "_reduced.mp4"
  EndIf
  
  ; --- Smart bitrates ---
  dimScale = 1.0
  If useDim And gInputWidth > 0 And gInputHeight > 0
    pctDim = GetGadgetState(#TRACK_DIM)
    dimScale = pctDim / 100.0
    newW = MakeEven(Round(gInputWidth * dimScale, #PB_Round_Nearest))
    newH = MakeEven(Round(gInputHeight * dimScale, #PB_Round_Nearest))
  EndIf
  
  If gInputBitrate > 0
    targetVideoBR = gInputBitrate
    If useDim And dimScale < 1.0 : targetVideoBR = Int(gInputBitrate * dimScale * dimScale) : EndIf
    If useSize : sizePct = GetGadgetState(#TRACK_SIZE) : targetVideoBR = Int(targetVideoBR * sizePct / 100.0) : EndIf
    If targetVideoBR < 10 : targetVideoBR = 10 : EndIf
  Else
    targetVideoBR = 0
  EndIf
  
  origAudioBR = 0
  If gInputBitrate > 0 And gInputDuration > 0.0 And gInputFileSize > 0
    overallBR = Int((gInputFileSize * 8.0) / (gInputDuration * 1000.0))
    origAudioBR = overallBR - gInputBitrate
    If origAudioBR < 32 : origAudioBR = 64 : EndIf
    If origAudioBR > 320 : origAudioBR = 128 : EndIf
  EndIf
  targetAudioBR = origAudioBR
  If targetAudioBR <= 0 : targetAudioBR = 64 : EndIf
  If targetAudioBR > 128 : targetAudioBR = 128 : EndIf
  
  ; --- Build args ---
  args = "-y -loglevel quiet -i " + Chr(34) + gInputFile + Chr(34)
  
  ; Video filter (scale)
  If useDim And gInputWidth > 0 And gInputHeight > 0
    args + " -vf scale=" + Str(newW) + ":" + Str(newH)
  EndIf
  
  ; Video codec
  If useSize Or useDim
    If targetVideoBR > 0
      args + " -c:v libx265 -b:v " + Str(targetVideoBR) + "k -preset medium -tag:v hvc1"
    Else
      If useSize : crf = CRFFromPercent(GetGadgetState(#TRACK_SIZE)) : Else : crf = 28 : EndIf
      args + " -c:v libx265 -crf " + Str(crf) + " -preset medium -tag:v hvc1"
    EndIf
  Else
    ; No video changes, just copy video stream
    args + " -c:v copy"
  EndIf
  
  ; Audio options: remove, denoise, or normal encode
  If removeAudio
    args + " -an"
    WriteLog("Audio: REMOVED")
  Else
    If denoiseAudio
      ; afftdn = FFT-based denoiser
      ; nr=20: noise reduction amount (0-97)
      ; nf=-30: noise floor in dB
      args + " -af afftdn=nr=20:nf=-30 -c:a aac -b:a " + Str(targetAudioBR) + "k"
      WriteLog("Audio: DENOISE + encode at " + Str(targetAudioBR) + "k")
    Else
      args + " -c:a aac -b:a " + Str(targetAudioBR) + "k"
      WriteLog("Audio: encode at " + Str(targetAudioBR) + "k")
    EndIf
  EndIf
  
  args + " -progress pipe:1 " + Chr(34) + savePath + Chr(34)
  
  WriteLog("Reduce args: " + args)
  
  ; Lock UI
  DisableGadget(#BTN_REDUCE, #True) : DisableGadget(#BTN_BROWSE_FILE, #True)
  HideGadget(#BTN_CANCEL_REDUCE, #False)
  SetGadgetText(#TXT_STATUS_REDUCE, "Reducing... 0%")
  
  proc = RunProgram(gFFmpegPath, args, "", #PB_Program_Open | #PB_Program_Read | #PB_Program_Hide)
  If proc = 0
    MessageRequester("Error", "Cannot run ffmpeg!")
    DisableGadget(#BTN_REDUCE, #False) : DisableGadget(#BTN_BROWSE_FILE, #False)
    HideGadget(#BTN_CANCEL_REDUCE, #True) : ProcedureReturn
  EndIf
  
  While ProgramRunning(proc)
    While AvailableProgramOutput(proc)
      line = ReadProgramString(proc)
      If Left(line, 12) = "out_time_ms="
        timeUs = ValD(Mid(line, 13)) : currentTime = timeUs / 1000000.0
        If gInputDuration > 0.0
          progressPct = Int((currentTime / gInputDuration) * 100.0)
          If progressPct > 100 : progressPct = 100 : EndIf
          If progressPct < 0 : progressPct = 0 : EndIf
          SetGadgetState(#PROG_REDUCE, progressPct)
          timeDisp = Str(Int(currentTime / 60)) + "m " + Str(Int(currentTime) % 60) + "s"
          SetGadgetText(#TXT_STATUS_REDUCE, "Reducing... " + Str(progressPct) + "%  (" + timeDisp + ")")
        Else
          SetGadgetText(#TXT_STATUS_REDUCE, "Reducing... " + Str(Int(currentTime)) + "s")
        EndIf
      EndIf
    Wend
    Repeat
      ev = WindowEvent()
      If ev = #PB_Event_Gadget And EventGadget() = #BTN_CANCEL_REDUCE : gCancelledReduce = #True : KillFFmpeg() : KillProgram(proc) : EndIf
      If ev = #PB_Event_CloseWindow : KillFFmpeg() : KillProgram(proc) : CloseProgram(proc) : End : EndIf
    Until ev = 0
    If gCancelledReduce : Break : EndIf
    Delay(50)
  Wend
  While AvailableProgramOutput(proc) : ReadProgramString(proc) : Wend
  CloseProgram(proc)
  
  If gCancelledReduce
    SetGadgetColor(#TXT_STATUS_REDUCE, #PB_Gadget_FrontColor, RGB(200, 0, 0))
    SetGadgetText(#TXT_STATUS_REDUCE, "Operation Cancelled!") : Delay(500)
    If FileSize(savePath) >= 0 : DeleteFile(savePath) : EndIf
  Else
    gLastSavePathReduce = savePath : SetGadgetState(#PROG_REDUCE, 100)
    SetGadgetColor(#TXT_STATUS_REDUCE, #PB_Gadget_FrontColor, RGB(0, 160, 0))
    newSize = FileSize(savePath) : origSize = gInputFileSize
    savedInfo = FormatFileSize(newSize)
    If origSize > 0 And newSize > 0
      If newSize < origSize
        savedPct = (1.0 - (newSize * 1.0 / origSize)) * 100.0
        savedInfo + "  |  Saved " + StrD(savedPct, 1) + "%"
      Else
        biggerPct = ((newSize * 1.0 / origSize) - 1.0) * 100.0
        savedInfo + "  |  Warning: " + StrD(biggerPct, 1) + "% bigger!"
      EndIf
    EndIf
    SetGadgetText(#TXT_STATUS_REDUCE, "By the Great Alzara!  (" + savedInfo + ")")
    HideGadget(#BTN_OPEN_FOLDER_REDUCE, #False) : HideGadget(#BTN_PLAY_VIDEO, #False)
    WriteLog("Reduce done. Orig: " + FormatFileSize(origSize) + " New: " + FormatFileSize(newSize))
    MessageRequester(#APP_TITLE, "Reduce completed!" + #CRLF$ + "Original: " + FormatFileSize(origSize) + #CRLF$ + "New size: " + savedInfo + #CRLF$ + "Saved: " + savePath)
  EndIf
  
  DisableGadget(#BTN_REDUCE, #False) : DisableGadget(#BTN_BROWSE_FILE, #False)
  HideGadget(#BTN_CANCEL_REDUCE, #True)
EndProcedure

; =====================================================================
; DoExtractAudio
; =====================================================================
Procedure DoExtractAudio()
  Protected savePath.s, proc, ev, line.s
  Protected timeUs.d, currentTime.d, progressPct, timeDisp.s, newSize.q
  
  Protected formatIdx = GetGadgetState(#COMBO_FORMAT)
  Protected ext.s, codecArgs.s
  
  Select formatIdx
    Case 0 : ext = ".mp3" : codecArgs = "-c:a libmp3lame -q:a 2"
    Case 1 : ext = ".m4a" : codecArgs = "-c:a aac -b:a 192k"
    Case 2 : ext = ".wav" : codecArgs = "-c:a pcm_s16le"
    Case 3 : ext = ".flac" : codecArgs = "-c:a flac"
    Case 4 : ext = ".ogg" : codecArgs = "-c:a libvorbis -q:a 5"
    Case 5 : ext = ".opus" : codecArgs = "-c:a libopus -b:a 128k"
    Case 6 : ext = ".m4a" : codecArgs = "-c:a copy"
    Default : ext = ".mp3" : codecArgs = "-c:a libmp3lame -q:a 2"
  EndSelect
  
  SetGadgetColor(#TXT_STATUS_AUDIO, #PB_Gadget_FrontColor, RGB(0, 0, 0))
  SetGadgetState(#PROG_AUDIO, 0)
  HideGadget(#BTN_OPEN_FOLDER_AUDIO, #True) : HideGadget(#BTN_PLAY_AUDIO, #True)
  gCancelledExtract = #False : gLastSavePathAudio = ""
  
  Protected baseName.s = GetFilePart(gAudioInputFile, #PB_FileSystem_NoExtension)
  Protected baseFolder.s = GetPathPart(gAudioInputFile)
  
  If Bool(GetGadgetState(#CHK_CUSTOM_SAVE_A) = #PB_Checkbox_Checked)
    savePath = SaveFileRequester("Save Audio As...", baseFolder + baseName + ext, "Audio (*" + ext + ")|*" + ext, 0)
    If savePath = "" : ProcedureReturn : EndIf
  Else : savePath = baseFolder + baseName + ext : EndIf
  
  Protected args.s = "-y -loglevel quiet -i " + Chr(34) + gAudioInputFile + Chr(34) + " -vn " + codecArgs + " -progress pipe:1 " + Chr(34) + savePath + Chr(34)
  WriteLog("Extract args: " + args)
  
  DisableGadget(#BTN_EXTRACT, #True) : DisableGadget(#BTN_BROWSE_AUDIO, #True)
  HideGadget(#BTN_CANCEL_EXTRACT, #False)
  SetGadgetText(#TXT_STATUS_AUDIO, "Extracting audio... 0%")
  
  proc = RunProgram(gFFmpegPath, args, "", #PB_Program_Open | #PB_Program_Read | #PB_Program_Hide)
  If proc = 0
    MessageRequester("Error", "Cannot run ffmpeg!")
    DisableGadget(#BTN_EXTRACT, #False) : DisableGadget(#BTN_BROWSE_AUDIO, #False)
    HideGadget(#BTN_CANCEL_EXTRACT, #True) : ProcedureReturn
  EndIf
  
  While ProgramRunning(proc)
    While AvailableProgramOutput(proc)
      line = ReadProgramString(proc)
      If Left(line, 12) = "out_time_ms="
        timeUs = ValD(Mid(line, 13)) : currentTime = timeUs / 1000000.0
        If gAudioInputDuration > 0.0
          progressPct = Int((currentTime / gAudioInputDuration) * 100.0)
          If progressPct > 100 : progressPct = 100 : EndIf
          If progressPct < 0 : progressPct = 0 : EndIf
          SetGadgetState(#PROG_AUDIO, progressPct)
          timeDisp = Str(Int(currentTime / 60)) + "m " + Str(Int(currentTime) % 60) + "s"
          SetGadgetText(#TXT_STATUS_AUDIO, "Extracting... " + Str(progressPct) + "%  (" + timeDisp + ")")
        Else
          SetGadgetText(#TXT_STATUS_AUDIO, "Extracting... " + Str(Int(currentTime)) + "s")
        EndIf
      EndIf
    Wend
    Repeat : ev = WindowEvent()
      If ev = #PB_Event_Gadget And EventGadget() = #BTN_CANCEL_EXTRACT : gCancelledExtract = #True : KillFFmpeg() : KillProgram(proc) : EndIf
      If ev = #PB_Event_CloseWindow : KillFFmpeg() : KillProgram(proc) : CloseProgram(proc) : End : EndIf
    Until ev = 0
    If gCancelledExtract : Break : EndIf : Delay(50)
  Wend
  While AvailableProgramOutput(proc) : ReadProgramString(proc) : Wend : CloseProgram(proc)
  
  If gCancelledExtract
    SetGadgetColor(#TXT_STATUS_AUDIO, #PB_Gadget_FrontColor, RGB(200, 0, 0))
    SetGadgetText(#TXT_STATUS_AUDIO, "Operation Cancelled!") : Delay(500)
    If FileSize(savePath) >= 0 : DeleteFile(savePath) : EndIf
  Else
    gLastSavePathAudio = savePath : SetGadgetState(#PROG_AUDIO, 100)
    SetGadgetColor(#TXT_STATUS_AUDIO, #PB_Gadget_FrontColor, RGB(0, 160, 0))
    newSize = FileSize(savePath)
    SetGadgetText(#TXT_STATUS_AUDIO, "By the Great Alzara!  (" + FormatFileSize(newSize) + ")")
    HideGadget(#BTN_OPEN_FOLDER_AUDIO, #False) : HideGadget(#BTN_PLAY_AUDIO, #False)
    WriteLog("Extract done. Size: " + FormatFileSize(newSize))
    MessageRequester(#APP_TITLE, "Audio extracted!" + #CRLF$ + "Size: " + FormatFileSize(newSize) + #CRLF$ + "Saved: " + savePath)
  EndIf
  
  DisableGadget(#BTN_EXTRACT, #False) : DisableGadget(#BTN_BROWSE_AUDIO, #False)
  HideGadget(#BTN_CANCEL_EXTRACT, #True)
EndProcedure

XIncludeFile "MergeVideo.pb"
XIncludeFile "ImageConvert.pb"
XIncludeFile "ImageSize.pb"

; =====================================================================
; MAIN UI
; =====================================================================

InitPaths()
gShlwapi = OpenLibrary(#PB_Any, "shlwapi.dll")
WriteLog("=== " + #APP_TITLE + " Started ===")

; Layout constants
#PW = 652                    ; panel width
#PAD = 10                    ; padding from edges
#CONTENT_W = #PW - 3 * #PAD  ; usable content width (622)

; Bottom-pinned Y positions
#STAT_Y  = 448
#PROG_Y  = #STAT_Y - 20
#BTN_Y   = #PROG_Y - 44
#CHK_Y   = #BTN_Y - 28
#BH      = 36

; Right-aligned buttons
#OF_W    = 100
#PL_W    = 100
#BG      = 8
#OF_X    = #PAD + #CONTENT_W - #OF_W
#PL_X    = #OF_X - #PL_W - #BG

If OpenWindow(#WIN_MAIN, 0, 0, 672, 530, #APP_TITLE, #PB_Window_SystemMenu | #PB_Window_ScreenCentered | #PB_Window_MinimizeGadget)
  EnableWindowDrop(#WIN_MAIN, #PB_Drop_Files, #PB_Drag_Copy)
  ; --- Menu Bar ---
  CreateMenu(0, WindowID(#WIN_MAIN))
  MenuTitle("Tools")
  MenuItem(#MENU_OPEN_LOG, "Open Log File")
  MenuTitle("Help")
  MenuItem(#MENU_ABOUT, "About Alzara Vision")
  
  PanelGadget(#PANEL_TABS, 5, 5, #PW, 500)
  
  ; ============================================
  ; TAB 1: MERGE VIDEO
  ; ============================================
  AddGadgetItem(#PANEL_TABS, -1, "Merge Video")
  
  TextGadget(#PB_Any, #PAD, 10, 120, 20, "Video Folder:")
  StringGadget(#STR_FOLDER, #PAD, 30, #CONTENT_W - 90, 25, "", #PB_String_ReadOnly)
  ButtonGadget(#BTN_BROWSE, #PAD + #CONTENT_W - 80, 30, 80, 25, "Browse...")
  
  #LIST_W = #CONTENT_W - 40
  #ARROW_X = #PAD + #LIST_W + 5
  #LIST_H = #CHK_Y - 105
  #LIST_BOTTOM = 65 + #LIST_H
  #ARROW_MID = 65 + #LIST_H / 2
  
  ListIconGadget(#LIST_VIDEOS, #PAD, 65, #LIST_W, #LIST_H, "#", 40, #PB_ListIcon_FullRowSelect | #PB_ListIcon_GridLines)
  AddGadgetColumn(#LIST_VIDEOS, 1, "File Name", #LIST_W - 180)
  AddGadgetColumn(#LIST_VIDEOS, 2, "Size", 100)
  
  ; Arrow buttons (vertical center of list)
  ButtonGadget(#BTN_MOVE_UP, #ARROW_X, #ARROW_MID - 34, 30, 30, Chr($25B2))
  ButtonGadget(#BTN_MOVE_DOWN, #ARROW_X, #ARROW_MID + 4, 30, 30, Chr($25BC))
  
  ; Toolbar below list (right-aligned): Sort, Reload, Remove
  #TB_Y = #LIST_BOTTOM + 4
  #TB_BTN_W = 30
  #TB_BTN_H = 26
  #TB_GAP = 4
  #TB_RIGHT = #PAD + #LIST_W
  
  ButtonGadget(#BTN_REMOVE_ITEM, #TB_RIGHT - #TB_BTN_W, #TB_Y, #TB_BTN_W, #TB_BTN_H, Chr($274C))
  SetGadgetColor(#BTN_REMOVE_ITEM, #PB_Gadget_FrontColor, RGB(200, 60, 60))
  
  ButtonGadget(#BTN_RELOAD_LIST, #TB_RIGHT - #TB_BTN_W * 2 - #TB_GAP, #TB_Y, #TB_BTN_W, #TB_BTN_H, Chr($21BB))
  SetGadgetColor(#BTN_RELOAD_LIST, #PB_Gadget_FrontColor, RGB(60, 160, 60))
  
  ButtonGadget(#BTN_SORT_AZ, #TB_RIGHT - #TB_BTN_W * 3 - #TB_GAP * 2, #TB_Y, #TB_BTN_W, #TB_BTN_H, "A" + Chr($2193))
  
  ; --- Bottom-pinned ---
  CheckBoxGadget(#CHK_CUSTOM_SAVE, #PAD, #CHK_Y, 400, 22, "Choose a different save location")
  ButtonGadget(#BTN_MERGE, #PAD, #BTN_Y, 140, #BH, "Start Merge")
  DisableGadget(#BTN_MERGE, #True)
  ButtonGadget(#BTN_CANCEL_MERGE, #PAD + 148, #BTN_Y, 90, #BH, "Cancel")
  HideGadget(#BTN_CANCEL_MERGE, #True)
  ButtonGadget(#BTN_OPEN_FOLDER_MERGE, #OF_X, #BTN_Y, #OF_W, #BH, "Open Folder")
  HideGadget(#BTN_OPEN_FOLDER_MERGE, #True)
  ProgressBarGadget(#PROG_MERGE, #PAD, #PROG_Y, #CONTENT_W, 14, 0, 100)
  TextGadget(#TXT_STATUS_MERGE, #PAD, #STAT_Y, #CONTENT_W, 18, "Ready. Select a folder containing MP4 video parts.")

  ; ============================================
  ; TAB 2: REDUCE SIZE
  ; ============================================
  AddGadgetItem(#PANEL_TABS, -1, "Video Size")
  
  TextGadget(#PB_Any, #PAD, 10, 120, 20, "Input Video:")
  StringGadget(#STR_INPUT_FILE, #PAD, 30, #CONTENT_W - 90, 25, "", #PB_String_ReadOnly)
  ButtonGadget(#BTN_BROWSE_FILE, #PAD + #CONTENT_W - 80, 30, 80, 25, "Browse...")
  TextGadget(#TXT_FILE_INFO, #PAD, 62, #CONTENT_W, 18, "")
  
  ; Frame: Quality/Size
  FrameGadget(#FRAME_SIZE, #PAD, 88, #CONTENT_W, 68, "Reduce by Quality / Size")
  CheckBoxGadget(#CHK_REDUCE_SIZE, 20, 108, 60, 20, "Enable")
  TextGadget(#TXT_SIZE_LABEL, 88, 110, 50, 18, "Quality:")
  TrackBarGadget(#TRACK_SIZE, 140, 105, 300, 25, 20, 100)
  SetGadgetState(#TRACK_SIZE, 50)
  TextGadget(#TXT_SIZE_VAL, 448, 110, 170, 18, "50% (Approximate)")
  
  ; Frame: Dimensions
  FrameGadget(#FRAME_DIM, #PAD, 165, #CONTENT_W, 85, "Reduce by Dimensions")
  CheckBoxGadget(#CHK_REDUCE_DIM, 20, 185, 60, 20, "Enable")
  TextGadget(#TXT_DIM_LABEL, 88, 187, 50, 18, "Scale:")
  TrackBarGadget(#TRACK_DIM, 140, 182, 300, 25, 10, 100)
  SetGadgetState(#TRACK_DIM, 50)
  TextGadget(#TXT_DIM_ORIG, 20, 215, 280, 18, "Original: - x -")
  TextGadget(#TXT_DIM_NEW, 310, 215, 300, 18, "New: - x -")
  
  ; Audio options
  CheckBoxGadget(#CHK_REMOVE_AUDIO, #PAD, 260, 250, 22, "Remove audio (mute video)")
  CheckBoxGadget(#CHK_NOISE_REDUCE, 280, 260, 280, 22, "Reduce audio noise (denoise)")
  
  ; --- Bottom-pinned ---
  CheckBoxGadget(#CHK_CUSTOM_SAVE_R, #PAD, #CHK_Y, 400, 22, "Choose a different save location")
  ButtonGadget(#BTN_REDUCE, #PAD, #BTN_Y, 140, #BH, "Reduce")
  DisableGadget(#BTN_REDUCE, #True)
  ButtonGadget(#BTN_CANCEL_REDUCE, #PAD + 148, #BTN_Y, 90, #BH, "Cancel")
  HideGadget(#BTN_CANCEL_REDUCE, #True)
  ButtonGadget(#BTN_PLAY_VIDEO, #PL_X, #BTN_Y, #PL_W, #BH, "Play Video")
  HideGadget(#BTN_PLAY_VIDEO, #True)
  ButtonGadget(#BTN_OPEN_FOLDER_REDUCE, #OF_X, #BTN_Y, #OF_W, #BH, "Open Folder")
  HideGadget(#BTN_OPEN_FOLDER_REDUCE, #True)
  ProgressBarGadget(#PROG_REDUCE, #PAD, #PROG_Y, #CONTENT_W, 14, 0, 100)
  TextGadget(#TXT_STATUS_REDUCE, #PAD, #STAT_Y, #CONTENT_W, 18, "Ready. Select an MP4 video file.")
  
  ; ============================================
  ; TAB 3: EXTRACT AUDIO
  ; ============================================
  AddGadgetItem(#PANEL_TABS, -1, "Extract Audio")
  
  TextGadget(#PB_Any, #PAD, 10, 120, 20, "Input Video:")
  StringGadget(#STR_AUDIO_INPUT, #PAD, 30, #CONTENT_W - 90, 25, "", #PB_String_ReadOnly)
  ButtonGadget(#BTN_BROWSE_AUDIO, #PAD + #CONTENT_W - 80, 30, 80, 25, "Browse...")
  TextGadget(#TXT_AUDIO_INFO, #PAD, 62, #CONTENT_W, 18, "")
  
  TextGadget(#TXT_FORMAT_LABEL, #PAD, 92, 100, 20, "Output Format:")
  ComboBoxGadget(#COMBO_FORMAT, 115, 89, 220, 25)
  AddGadgetItem(#COMBO_FORMAT, -1, "MP3 (lossy, universal)")
  AddGadgetItem(#COMBO_FORMAT, -1, "AAC / M4A (lossy, high quality)")
  AddGadgetItem(#COMBO_FORMAT, -1, "WAV (lossless, large)")
  AddGadgetItem(#COMBO_FORMAT, -1, "FLAC (lossless, compressed)")
  AddGadgetItem(#COMBO_FORMAT, -1, "OGG Vorbis (lossy, open)")
  AddGadgetItem(#COMBO_FORMAT, -1, "OPUS (lossy, best quality/size)")
  AddGadgetItem(#COMBO_FORMAT, -1, "Copy Original (fastest)")
  SetGadgetState(#COMBO_FORMAT, 0)
  
  ; --- Bottom-pinned ---
  CheckBoxGadget(#CHK_CUSTOM_SAVE_A, #PAD, #CHK_Y, 400, 22, "Choose a different save location")
  ButtonGadget(#BTN_EXTRACT, #PAD, #BTN_Y, 140, #BH, "Extract Audio")
  DisableGadget(#BTN_EXTRACT, #True)
  ButtonGadget(#BTN_CANCEL_EXTRACT, #PAD + 148, #BTN_Y, 90, #BH, "Cancel")
  HideGadget(#BTN_CANCEL_EXTRACT, #True)
  ButtonGadget(#BTN_PLAY_AUDIO, #PL_X, #BTN_Y, #PL_W, #BH, "Play Audio")
  HideGadget(#BTN_PLAY_AUDIO, #True)
  ButtonGadget(#BTN_OPEN_FOLDER_AUDIO, #OF_X, #BTN_Y, #OF_W, #BH, "Open Folder")
  HideGadget(#BTN_OPEN_FOLDER_AUDIO, #True)
  ProgressBarGadget(#PROG_AUDIO, #PAD, #PROG_Y, #CONTENT_W, 14, 0, 100)
  TextGadget(#TXT_STATUS_AUDIO, #PAD, #STAT_Y, #CONTENT_W, 18, "Ready. Select a video file to extract audio.")
  
    ; ============================================
  ; TAB 4: IMAGE CONVERT
  ; ============================================
  AddGadgetItem(#PANEL_TABS, -1, "Image Convert")
  
  TextGadget(#PB_Any, #PAD, 10, 50, 20, "Mode:")
  ComboBoxGadget(#COMBO_IMG_MODE, 60, 8, 130, 25)
  AddGadgetItem(#COMBO_IMG_MODE, -1, "Single File")
  AddGadgetItem(#COMBO_IMG_MODE, -1, "Folder (Batch)")
  SetGadgetState(#COMBO_IMG_MODE, 0)
  
  TextGadget(#PB_Any, #PAD, 42, 50, 20, "Input:")
  StringGadget(#STR_IMG_INPUT, 60, 40, #CONTENT_W - 150, 25, "", #PB_String_ReadOnly)
  ButtonGadget(#BTN_BROWSE_IMG, #PAD + #CONTENT_W - 80, 40, 80, 25, "Browse...")
  TextGadget(#TXT_IMG_INFO, #PAD, 72, #CONTENT_W, 18, "")
  
  TextGadget(#TXT_IMG_FORMAT_LABEL, #PAD, 102, 100, 20, "Output Format:")
  ComboBoxGadget(#COMBO_IMG_FORMAT, 115, 99, 150, 25)
  AddGadgetItem(#COMBO_IMG_FORMAT, -1, "JPG (lossy, small)")
  AddGadgetItem(#COMBO_IMG_FORMAT, -1, "PNG (lossless)")
  AddGadgetItem(#COMBO_IMG_FORMAT, -1, "WEBP (modern, small)")
  SetGadgetState(#COMBO_IMG_FORMAT, 0)
  
  TextGadget(#TXT_IMG_QUALITY_LABEL, #PAD, 138, 60, 20, "Quality:")
  TrackBarGadget(#TRACK_IMG_QUALITY, 75, 135, 250, 25, 1, 100)
  SetGadgetState(#TRACK_IMG_QUALITY, 92)
  TextGadget(#TXT_IMG_QUALITY_VAL, 335, 138, 50, 20, "92%")
  
  ; --- Bottom-pinned ---
  CheckBoxGadget(#CHK_CUSTOM_SAVE_IMG, #PAD, #CHK_Y, 400, 22, "Choose a different save location")
  ButtonGadget(#BTN_IMG_CONVERT, #PAD, #BTN_Y, 140, #BH, "Convert")
  DisableGadget(#BTN_IMG_CONVERT, #True)
  ButtonGadget(#BTN_CANCEL_IMG, #PAD + 148, #BTN_Y, 90, #BH, "Cancel")
  HideGadget(#BTN_CANCEL_IMG, #True)
  ButtonGadget(#BTN_OPEN_FOLDER_IMG, #OF_X, #BTN_Y, #OF_W, #BH, "Open Folder")
  HideGadget(#BTN_OPEN_FOLDER_IMG, #True)
  ProgressBarGadget(#PROG_IMG, #PAD, #PROG_Y, #CONTENT_W, 14, 0, 100)
  TextGadget(#TXT_STATUS_IMG, #PAD, #STAT_Y, #CONTENT_W, 18, "Ready. Select input and click Convert.")
  
  ; ============================================
  ; TAB 5: IMAGE SIZE
  ; ============================================
  AddGadgetItem(#PANEL_TABS, -1, "Image Size")
  
  TextGadget(#PB_Any, #PAD, 10, 80, 20, "Input Image:")
  StringGadget(#STR_IMGSZ_INPUT, #PAD, 30, #CONTENT_W - 90, 25, "", #PB_String_ReadOnly)
  ButtonGadget(#BTN_BROWSE_IMGSZ, #PAD + #CONTENT_W - 80, 30, 80, 25, "Browse...")
  TextGadget(#TXT_IMGSZ_INFO, #PAD, 62, #CONTENT_W, 18, "")
  
  ; Frame: Scale by Percentage
  FrameGadget(#FRAME_IMGSZ_SLIDER, #PAD, 88, #CONTENT_W, 80, "Resize by Percentage")
  CheckBoxGadget(#CHK_IMGSZ_SLIDER, 20, 108, 60, 20, "Enable")
  SetGadgetState(#CHK_IMGSZ_SLIDER, #PB_Checkbox_Checked)
  TextGadget(#TXT_IMGSZ_SCALE_LABEL, 88, 110, 45, 18, "Scale:")
  TrackBarGadget(#TRACK_IMGSZ_SCALE, 135, 105, 300, 25, 5, 100)
  SetGadgetState(#TRACK_IMGSZ_SCALE, 50)
  TextGadget(#TXT_IMGSZ_ORIG, 20, 140, 280, 18, "Original: - x -")
  TextGadget(#TXT_IMGSZ_NEW, 310, 140, 310, 18, "New: - x -")
  
  ; Frame: Manual Dimensions
  FrameGadget(#FRAME_IMGSZ_MANUAL, #PAD, 176, #CONTENT_W, 60, "Manual Dimensions")
  TextGadget(#TXT_IMGSZ_W_LABEL, 20, 198, 40, 18, "Width:")
  StringGadget(#STR_IMGSZ_W, 62, 195, 70, 22, "0", #PB_String_Numeric)
  TextGadget(#TXT_IMGSZ_X, 140, 198, 15, 18, "x")
  TextGadget(#PB_Any, 160, 198, 45, 18, "Height:")
  StringGadget(#STR_IMGSZ_H, 210, 195, 70, 22, "0", #PB_String_Numeric)
  CheckBoxGadget(#CHK_IMGSZ_ASPECT, 300, 196, 200, 20, "Keep aspect ratio")
  SetGadgetState(#CHK_IMGSZ_ASPECT, #PB_Checkbox_Checked)
  
  ; Algorithm selection
  TextGadget(#TXT_IMGSZ_ALGO_LABEL, #PAD, 248, 70, 20, "Algorithm:")
  ComboBoxGadget(#COMBO_IMGSZ_ALGO, 85, 245, 350, 25)
  AddGadgetItem(#COMBO_IMGSZ_ALGO, -1, "Fast Bilinear  -  Fastest, lower quality")
  AddGadgetItem(#COMBO_IMGSZ_ALGO, -1, "Bilinear  -  Fast, smooth results")
  AddGadgetItem(#COMBO_IMGSZ_ALGO, -1, "Bicubic  -  Balanced speed and quality")
  AddGadgetItem(#COMBO_IMGSZ_ALGO, -1, "Lanczos  -  Best quality, sharpest (slower)")
  SetGadgetState(#COMBO_IMGSZ_ALGO, 3)
  
  ; Quality
  TextGadget(#TXT_IMGSZ_QUALITY_LABEL, #PAD, 280, 60, 20, "Quality:")
  TrackBarGadget(#TRACK_IMGSZ_QUALITY, 75, 277, 250, 25, 1, 100)
  SetGadgetState(#TRACK_IMGSZ_QUALITY, 92)
  TextGadget(#TXT_IMGSZ_QUALITY_VAL, 335, 280, 50, 20, "92%")
  
  ; --- Bottom-pinned ---
  CheckBoxGadget(#CHK_CUSTOM_SAVE_IMGSZ, #PAD, #CHK_Y, 400, 22, "Choose a different save location")
  ButtonGadget(#BTN_IMGSZ_RESIZE, #PAD, #BTN_Y, 140, #BH, "Resize")
  DisableGadget(#BTN_IMGSZ_RESIZE, #True)
  ButtonGadget(#BTN_CANCEL_IMGSZ, #PAD + 148, #BTN_Y, 90, #BH, "Cancel")
  HideGadget(#BTN_CANCEL_IMGSZ, #True)
  ButtonGadget(#BTN_OPEN_FOLDER_IMGSZ, #OF_X, #BTN_Y, #OF_W, #BH, "Open Folder")
  HideGadget(#BTN_OPEN_FOLDER_IMGSZ, #True)
  ProgressBarGadget(#PROG_IMGSZ, #PAD, #PROG_Y, #CONTENT_W, 14, 0, 100)
  TextGadget(#TXT_STATUS_IMGSZ, #PAD, #STAT_Y, #CONTENT_W, 18, "Ready. Select an image file.")
  
  CloseGadgetList()
  
  ; =====================================================================
  ; EVENT LOOP
  ; =====================================================================
  Define ev, folder.s, filePath.s
  
  Repeat
    ev = WaitWindowEvent()
    Select ev
      Case #PB_Event_CloseWindow
        WriteLog("=== " + #APP_NAME + " Closed ===")
        If gShlwapi : CloseLibrary(gShlwapi) : EndIf
        End
      
      Case #PB_Event_WindowDrop
          Define dropFiles.s = EventDropFiles()
          Define droppedItem.s = StringField(dropFiles, 1, #LF$) 
          
          If droppedItem <> ""
              Define activeTab = GetGadgetState(#PANEL_TABS)
              
              Select activeTab
                 Case 0
                      If FileSize(droppedItem) = -2
                          gSourceFolder = droppedItem
                          If Right(gSourceFolder, 1) <> "\" And Right(gSourceFolder, 1) <> "/"
                              gSourceFolder + "\"
                          EndIf                          
                          ; (اختیاری) اگر تابع شما به تغییر مسیر جاری ویندوز وابسته است خط زیر را هم از کامنت خارج کنید:
                          ; SetCurrentDirectory(gSourceFolder)
                          ; -------------------------------------
                          
                          SetGadgetText(#STR_FOLDER, gSourceFolder)
                          ScanFolder(gSourceFolder)
                      Else
                          MessageRequester("Alzara Vision", "Please drag and drop a FOLDER for Merge Video.")
                      EndIf
                      
                  Case 1 
                      If FileSize(droppedItem) >= 0
                          LoadInputFile(droppedItem)
                      EndIf
                      
                  Case 2
                      If FileSize(droppedItem) >= 0
                          LoadAudioInputFile(droppedItem)
                      EndIf
                      
                  Case 3
                      If GetGadgetState(#COMBO_IMG_MODE) = 0
                          If FileSize(droppedItem) >= 0
                              SetGadgetText(#STR_IMG_INPUT, droppedItem)
                          EndIf
                      Else
                          If FileSize(droppedItem) = -2
                              SetGadgetText(#STR_IMG_INPUT, droppedItem)
                          EndIf
                      EndIf
                      
                  Case 4
                      If FileSize(droppedItem) >= 0
                          SetGadgetText(#STR_IMGSZ_INPUT, droppedItem)
                      EndIf
              EndSelect
          EndIf
      ; ---------------------------------------        
      Case #PB_Event_Menu
        Select EventMenu()
          Case #MENU_OPEN_LOG
            If FileSize(gLogFile) > 0 : RunProgram("notepad.exe", gLogFile, "")
            Else : MessageRequester("Log", "No log file found.") : EndIf
          Case #MENU_ABOUT
            ShowAbout()
        EndSelect
        
      Case #PB_Event_Gadget
        Select EventGadget()
          
          ; --- Merge Video ---
          Case #BTN_BROWSE
            folder = PathRequester("Select folder with MP4 parts", "")
            If folder <> ""
              gSourceFolder = folder
              SetGadgetText(#STR_FOLDER, gSourceFolder)
              ScanFolder(gSourceFolder)
            EndIf
          Case #BTN_MERGE : DoMerge()
          Case #BTN_OPEN_FOLDER_MERGE : OpenFolder(gLastSavePathMerge)
          Case #BTN_MOVE_UP : MoveItemUp()
          Case #BTN_MOVE_DOWN : MoveItemDown()
          Case #BTN_REMOVE_ITEM : RemoveSelectedItem()
          Case #BTN_RELOAD_LIST : ReloadFolder()
          Case #BTN_SORT_AZ : DoSortToggle()
          Case #LIST_VIDEOS
            If EventType() = #PB_EventType_LeftDoubleClick
              PlaySelectedVideo()
            EndIf
          
          ; --- Video Size (Reduce) ---
          Case #BTN_BROWSE_FILE
            filePath = OpenFileRequester("Select MP4 Video", "", "MP4 Video (*.mp4)|*.mp4", 0)
            If filePath <> "" : LoadInputFile(filePath) : EndIf
          Case #TRACK_SIZE : UpdateSizePreview()
          Case #TRACK_DIM : UpdateDimPreview()
          Case #CHK_REMOVE_AUDIO
            If GetGadgetState(#CHK_REMOVE_AUDIO) = #PB_Checkbox_Checked
              SetGadgetState(#CHK_NOISE_REDUCE, #PB_Checkbox_Unchecked)
              DisableGadget(#CHK_NOISE_REDUCE, #True)
            Else
              DisableGadget(#CHK_NOISE_REDUCE, #False)
            EndIf
          Case #BTN_REDUCE : DoReduce()
          Case #BTN_OPEN_FOLDER_REDUCE : OpenFolder(gLastSavePathReduce)
          Case #BTN_PLAY_VIDEO
            If gLastSavePathReduce <> "" : RunProgram(gLastSavePathReduce, "", "") : EndIf
          
          ; --- Extract Audio ---
          Case #BTN_BROWSE_AUDIO
            filePath = OpenFileRequester("Select Video File", "", "Video (*.mp4;*.mkv;*.avi;*.mov)|*.mp4;*.mkv;*.avi;*.mov|All (*.*)|*.*", 0)
            If filePath <> "" : LoadAudioInputFile(filePath) : EndIf
          Case #BTN_EXTRACT : DoExtractAudio()
          Case #BTN_OPEN_FOLDER_AUDIO : OpenFolder(gLastSavePathAudio)
          Case #BTN_PLAY_AUDIO
            If gLastSavePathAudio <> "" : RunProgram(gLastSavePathAudio, "", "") : EndIf
          
          ; --- Image Convert ---
          Case #COMBO_IMG_MODE : OnImgModeChange()
          Case #BTN_BROWSE_IMG : LoadImageInput()
          Case #TRACK_IMG_QUALITY : UpdateImgQualityLabel()
          Case #BTN_IMG_CONVERT : DoImageConvert()
          Case #BTN_OPEN_FOLDER_IMG : OpenFolder(gImgLastSavePath)
          
          ; --- Image Size ---
          Case #BTN_BROWSE_IMGSZ : LoadImgSzInput()
          Case #TRACK_IMGSZ_SCALE : UpdateImgSzPreview()
          Case #TRACK_IMGSZ_QUALITY
            SetGadgetText(#TXT_IMGSZ_QUALITY_VAL, Str(GetGadgetState(#TRACK_IMGSZ_QUALITY)) + "%")
          Case #STR_IMGSZ_W : UpdateImgSzFromWidth()
          Case #STR_IMGSZ_H : UpdateImgSzFromHeight()
          Case #BTN_IMGSZ_RESIZE : DoImageResize()
          Case #BTN_OPEN_FOLDER_IMGSZ : OpenFolder(gImgSzLastSavePath)
          
        EndSelect
    EndSelect
  ForEver
EndIf





    

; IDE Options = PureBasic 6.20 (Windows - x64)
; CursorPosition = 11
; Folding = ----
; EnableXP
; DPIAware
; UseIcon = icon.ico
; Executable = Alzara Visions.exe
; IncludeVersionInfo
; VersionField0 = 1.0