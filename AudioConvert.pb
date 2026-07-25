; ======================================================================
; Module : AudioConvert.pb
; Purpose: Convert Audio files, edit metadata (ID3), change bitrate/sample rate
; Usage  : XIncludeFile "AudioConvert.pb" in main file
; ======================================================================

Global gACInputPath.s = ""
Global gACLastSavePath.s = ""
Global gACCancelled = #False
Global gACDuration.d = 0.0
Global gACFileSize.q = 0
Global gACBitrate = 0
Global gACSampleRate = 0
Global gACChannels.s = ""

; =====================================================================
; Parse Audio Info and Metadata
; =====================================================================
Procedure ProbeAudioConvertInfo(filePath.s)
  Protected batFile.s = gTempDir + "alzara_acprobe.bat"
  Protected outFile.s = gTempDir + "alzara_acprobe_out.txt"
  Protected allOutput.s, pos, line.s, k
  
  gACDuration = 0.0
  gACBitrate = 0
  gACSampleRate = 0
  gACChannels = ""
  
  ; Reset Metadata Fields
  SetGadgetText(#STR_AC_META_TITLE, "")
  SetGadgetText(#STR_AC_META_ARTIST, "")
  SetGadgetText(#STR_AC_META_ALBUM, "")
  SetGadgetText(#STR_AC_META_YEAR, "")
  SetGadgetText(#STR_AC_META_GENRE, "")
  SetGadgetText(#STR_AC_META_DESC, "")
  
  If FileSize(outFile) >= 0 : DeleteFile(outFile) : EndIf
  Protected cmd.s = Chr(34) + gFFmpegPath + Chr(34) + " -i " + Chr(34) + filePath + Chr(34) + " 2>" + Chr(34) + outFile + Chr(34)
  If WriteBatFile(batFile, cmd) = "" : ProcedureReturn : EndIf
  RunBatAndWait(batFile) : Delay(100)
  allOutput = ReadEntireFile(outFile)
  
  ; Extract Duration
  pos = FindString(allOutput, "Duration:")
  If pos > 0
    Protected durStr.s = Mid(allOutput, pos + 10, 11)
    gACDuration = ValD(Mid(durStr, 1, 2)) * 3600.0 + ValD(Mid(durStr, 4, 2)) * 60.0 + ValD(Mid(durStr, 7, 5))
  EndIf
  
  ; Extract Bitrate, Sample Rate, and Channels
  pos = FindString(allOutput, "Audio:")
  If pos > 0
    Protected audioLine.s = Mid(allOutput, pos, 300)
    
    ; Parse Sample Rate (Hz)
    Protected hzPos = FindString(audioLine, " Hz")
    If hzPos > 0
      Protected hzStart = hzPos - 1
      While hzStart > 0 And Mid(audioLine, hzStart, 1) >= "0" And Mid(audioLine, hzStart, 1) <= "9" : hzStart - 1 : Wend
      hzStart + 1
      gACSampleRate = Val(Mid(audioLine, hzStart, hzPos - hzStart))
      
      ; Parse Channels (Text between commas after Hz)
      Protected chStart = FindString(audioLine, ",", hzPos)
      If chStart > 0
        chStart + 1
        While Mid(audioLine, chStart, 1) = " " : chStart + 1 : Wend ; Skip spaces
        Protected chEnd = FindString(audioLine, ",", chStart)
        If chEnd > chStart
          gACChannels = Trim(Mid(audioLine, chStart, chEnd - chStart))
        EndIf
      EndIf
    EndIf
    
    ; Parse Bitrate (kb/s)
    Protected kbpsPos = FindString(audioLine, "kb/s")
    If kbpsPos > 0
      Protected kbpsStart = kbpsPos - 2
      While kbpsStart > 0 And Mid(audioLine, kbpsStart, 1) >= "0" And Mid(audioLine, kbpsStart, 1) <= "9" : kbpsStart - 1 : Wend
      kbpsStart + 1
      gACBitrate = Val(Mid(audioLine, kbpsStart, kbpsPos - kbpsStart))
    EndIf
  EndIf
  
  ; Extract Metadata (ID3 Tags)
  Protected numLines = CountString(allOutput, Chr(10)) + 1
  Protected i
  For i = 1 To numLines
    line = Trim(StringField(allOutput, i, Chr(10)))
    pos = FindString(line, ":")
    If pos > 0 And pos < 20
      Protected key.s = Trim(LCase(Left(line, pos - 1)))
      Protected val.s = Trim(Mid(line, pos + 1))
      Select key
        Case "title"  : SetGadgetText(#STR_AC_META_TITLE, val)
        Case "artist" : SetGadgetText(#STR_AC_META_ARTIST, val)
        Case "album"  : SetGadgetText(#STR_AC_META_ALBUM, val)
        Case "date", "year", "tyer" : SetGadgetText(#STR_AC_META_YEAR, val)
        Case "genre"  : SetGadgetText(#STR_AC_META_GENRE, val)
        Case "description", "comment" : SetGadgetText(#STR_AC_META_DESC, val)
      EndSelect
    EndIf
  Next
  
  DeleteFile(batFile) : DeleteFile(outFile)
EndProcedure

; =====================================================================
; Load Audio Input
; =====================================================================
Procedure LoadAudioConvertInput()
  Protected path.s, info.s
  path = OpenFileRequester("Select Audio File", "", "Audio Files (*.mp3;*.wav;*.m4a;*.ogg;*.flac;*.wma;*.aac)|*.mp3;*.wav;*.m4a;*.ogg;*.flac;*.wma;*.aac|All (*.*)|*.*", 0)
  If path = "" : ProcedureReturn : EndIf
  
  gACInputPath = path
  SetGadgetText(#STR_AC_INPUT, path)
  SetGadgetColor(#TXT_STATUS_AC, #PB_Gadget_FrontColor, RGB(0, 0, 0))
  SetGadgetState(#PROG_AC, 0)
  HideGadget(#BTN_OPEN_FOLDER_AC, #True)
  
  SetGadgetText(#TXT_STATUS_AC, "Analyzing metadata...")
  SetGadgetText(#TXT_AC_INFO, "Analyzing...")
  Repeat : Until WindowEvent() = 0
  
  gACFileSize = FileSize(path)
  ProbeAudioConvertInfo(path)
  
  ; ساخت متن اطلاعات فایل به صورت پویا
  info = FormatFileSize(gACFileSize) + "  |  " + UCase(GetExtensionPart(path))
  If gACDuration > 0.0 : info + "  |  " + Str(Int(gACDuration / 60)) + "m " + Str(Int(gACDuration) % 60) + "s" : EndIf
  If gACBitrate > 0 : info + "  |  " + Str(gACBitrate) + " kb/s" : EndIf
  If gACSampleRate > 0 : info + "  |  " + Str(gACSampleRate) + " Hz" : EndIf
  If gACChannels <> "" : info + "  |  " + UCase(Left(gACChannels, 1)) + LCase(Mid(gACChannels, 2)) : EndIf
  
  SetGadgetText(#TXT_AC_INFO, info)
  DisableGadget(#BTN_AC_CONVERT, #False)
  SetGadgetText(#TXT_STATUS_AC, "Ready. Adjust settings and click Convert.")
EndProcedure

; =====================================================================
; Build and Run Conversion
; =====================================================================
Procedure DoAudioConvert()
  Protected savePath.s, args.s, proc, ev, line.s
  Protected timeUs.d, currentTime.d, progressPct, timeDisp.s
  
  If gACInputPath = ""
    MessageRequester("Alzara Vision", "Please select an input audio file.")
    ProcedureReturn
  EndIf
  
  ; Get UI Selections
  Protected fmtIdx = GetGadgetState(#COMBO_AC_FORMAT)
  Protected brIdx  = GetGadgetState(#COMBO_AC_BITRATE)
  Protected srIdx  = GetGadgetState(#COMBO_AC_SAMPLERATE)
  Protected chIdx  = GetGadgetState(#COMBO_AC_CHANNELS)
  
  Protected ext.s, codec.s
  Select fmtIdx
    Case 0 : ext = "mp3"  : codec = "libmp3lame"
    Case 1 : ext = "m4a"  : codec = "aac"
    Case 2 : ext = "wav"  : codec = "pcm_s16le"
    Case 3 : ext = "flac" : codec = "flac"
    Case 4 : ext = "ogg"  : codec = "libvorbis"
  EndSelect
  
  Protected baseName.s = GetFilePart(gACInputPath, #PB_FileSystem_NoExtension)
  Protected baseFolder.s = GetPathPart(gACInputPath)
  
  If Bool(GetGadgetState(#CHK_CUSTOM_SAVE_AC) = #PB_Checkbox_Checked)
    savePath = SaveFileRequester("Save Audio As...", baseFolder + baseName + "_converted." + ext, UCase(ext) + " (*." + ext + ")|*." + ext, 0)
    If savePath = "" : ProcedureReturn : EndIf
  Else
    savePath = baseFolder + baseName + "_converted." + ext
  EndIf
  
  SetGadgetColor(#TXT_STATUS_AC, #PB_Gadget_FrontColor, RGB(0, 0, 0))
  SetGadgetState(#PROG_AC, 0)
  HideGadget(#BTN_OPEN_FOLDER_AC, #True)
  gACCancelled = #False : gACLastSavePath = ""
  
  ; Start Building FFmpeg Args
  args = "-y -loglevel quiet -i " + Chr(34) + gACInputPath + Chr(34) + " -c:a " + codec
  
  ; Bitrate (Skip for lossless like WAV and FLAC)
  If ext <> "wav" And ext <> "flac" And brIdx > 0
    Protected br.s = GetGadgetItemText(#COMBO_AC_BITRATE, brIdx)
    args + " -b:a " + br
  EndIf
  
  ; Sample Rate
  If srIdx > 0
    Protected sr.s = GetGadgetItemText(#COMBO_AC_SAMPLERATE, srIdx)
    args + " -ar " + sr
  EndIf
  
  ; Channels
  If chIdx = 1 : args + " -ac 1" : EndIf ; Mono
  If chIdx = 2 : args + " -ac 2" : EndIf ; Stereo
  
  ; Metadata
  Protected mTitle.s  = ReplaceString(GetGadgetText(#STR_AC_META_TITLE), Chr(34), "'")
  Protected mArtist.s = ReplaceString(GetGadgetText(#STR_AC_META_ARTIST), Chr(34), "'")
  Protected mAlbum.s  = ReplaceString(GetGadgetText(#STR_AC_META_ALBUM), Chr(34), "'")
  Protected mYear.s   = ReplaceString(GetGadgetText(#STR_AC_META_YEAR), Chr(34), "'")
  Protected mGenre.s  = ReplaceString(GetGadgetText(#STR_AC_META_GENRE), Chr(34), "'")
  Protected mDesc.s   = ReplaceString(GetGadgetText(#STR_AC_META_DESC), Chr(34), "'")
  
  ; ارسال صریح تمام مقادیر (حتی خالی‌ها) به ffmpeg برای حذف متادیتا در صورت پاک شدن توسط کاربر
  args + " -metadata title=" + Chr(34) + mTitle + Chr(34)
  args + " -metadata artist=" + Chr(34) + mArtist + Chr(34)
  args + " -metadata album=" + Chr(34) + mAlbum + Chr(34)
  args + " -metadata date=" + Chr(34) + mYear + Chr(34) + " -metadata year=" + Chr(34) + mYear + Chr(34)
  args + " -metadata genre=" + Chr(34) + mGenre + Chr(34)
  args + " -metadata description=" + Chr(34) + mDesc + Chr(34) + " -metadata comment=" + Chr(34) + mDesc + Chr(34)
  
  args + " -progress pipe:1 " + Chr(34) + savePath + Chr(34)
  WriteLog("AudioConvert Args: " + args)
  
  DisableGadget(#BTN_AC_CONVERT, #True) : DisableGadget(#BTN_BROWSE_AC, #True)
  HideGadget(#BTN_CANCEL_AC, #False)
  SetGadgetText(#TXT_STATUS_AC, "Converting audio... 0%")
  
  proc = RunProgram(gFFmpegPath, args, "", #PB_Program_Open | #PB_Program_Read | #PB_Program_Hide)
  If proc = 0
    MessageRequester("Error", "Cannot run ffmpeg!")
    DisableGadget(#BTN_AC_CONVERT, #False) : DisableGadget(#BTN_BROWSE_AC, #False)
    HideGadget(#BTN_CANCEL_AC, #True) : ProcedureReturn
  EndIf
  
  While ProgramRunning(proc)
    While AvailableProgramOutput(proc)
      line = ReadProgramString(proc)
      If Left(line, 12) = "out_time_ms="
        timeUs = ValD(Mid(line, 13)) : currentTime = timeUs / 1000000.0
        If gACDuration > 0.0
          progressPct = Int((currentTime / gACDuration) * 100.0)
          If progressPct > 100 : progressPct = 100 : EndIf
          If progressPct < 0 : progressPct = 0 : EndIf
          SetGadgetState(#PROG_AC, progressPct)
          timeDisp = Str(Int(currentTime / 60)) + "m " + Str(Int(currentTime) % 60) + "s"
          SetGadgetText(#TXT_STATUS_AC, "Converting... " + Str(progressPct) + "%  (" + timeDisp + ")")
        Else
          SetGadgetText(#TXT_STATUS_AC, "Converting... " + Str(Int(currentTime)) + "s")
        EndIf
      EndIf
    Wend
    Repeat : ev = WindowEvent()
      If ev = #PB_Event_Gadget And EventGadget() = #BTN_CANCEL_AC : gACCancelled = #True : KillFFmpeg() : KillProgram(proc) : EndIf
      If ev = #PB_Event_CloseWindow : KillFFmpeg() : KillProgram(proc) : CloseProgram(proc) : End : EndIf
    Until ev = 0
    If gACCancelled : Break : EndIf : Delay(50)
  Wend
  While AvailableProgramOutput(proc) : ReadProgramString(proc) : Wend : CloseProgram(proc)
  
  If gACCancelled
    SetGadgetColor(#TXT_STATUS_AC, #PB_Gadget_FrontColor, RGB(200, 0, 0))
    SetGadgetText(#TXT_STATUS_AC, "Operation Cancelled!") : Delay(500)
    If FileSize(savePath) >= 0 : DeleteFile(savePath) : EndIf
  Else
    gACLastSavePath = savePath : SetGadgetState(#PROG_AC, 100)
    SetGadgetColor(#TXT_STATUS_AC, #PB_Gadget_FrontColor, RGB(0, 160, 0))
    Protected newSize.q = FileSize(savePath)
    SetGadgetText(#TXT_STATUS_AC, "By the Great Alzara!  (" + FormatFileSize(newSize) + ")")
    HideGadget(#BTN_OPEN_FOLDER_AC, #False)
    WriteLog("Audio Convert done. Size: " + FormatFileSize(newSize))
    MessageRequester(#APP_TITLE, "Audio converted!" + #CRLF$ + "Size: " + FormatFileSize(newSize) + #CRLF$ + "Saved: " + savePath)
  EndIf
  
  DisableGadget(#BTN_AC_CONVERT, #False) : DisableGadget(#BTN_BROWSE_AC, #False)
  HideGadget(#BTN_CANCEL_AC, #True)
EndProcedure
; IDE Options = PureBasic 6.20 (Windows - x64)
; CursorPosition = 209
; FirstLine = 175
; Folding = -
; EnableXP
; DPIAware