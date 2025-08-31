#Requires AutoHotkey v2.0
#SingleInstance Force

#Include Lib\Discord-Webhook-master\lib\resources\JSON.ahk
#Include Lib\GUI\!CreateImageButton.ahk
#Include Lib\GUI\!WinDarkUI.ahk
#Include Lib\GUI\!GuiEnchancerKit.ahk
#Include Lib\GUI\!DarkStyleMsgBox.ahk
#Include Lib\Gdip_All.ahk
#DllLoad "Gdiplus.dll"

fileName := RegExReplace(A_ScriptFullPath, ".*\.([^.]+)$", "$1")

if fileName != "ahk" {
    if (!A_IsAdmin && !InStr(DllCall("GetCommandLine", "str"), ' /restart')) {
        try
            if A_IsCompiled
                Run('*RunAs "' A_ScriptFullPath '" /restart')
            else Run('*RunAs "' A_AhkPath '" /restart "' A_ScriptFullPath '"')
        finally ExitApp()
    }
}

Reg := "HKEY_CURRENT_USER\Software\Pantheon\Loader"

FirstLaunchProtocol() {
    if A_IsAdmin {
        if !RegExist("HKEY_CLASSES_ROOT\pantheon") {
            RegCreateKey("HKEY_CLASSES_ROOT\pantheon\shell\open\command")
            RegWrite("", "REG_SZ", "HKEY_CLASSES_ROOT\pantheon", "URL Protocol")
            RegWrite("URL:pantheon", "REG_SZ", "HKEY_CLASSES_ROOT\pantheon")
        }
        RegWrite('"' A_ScriptFullPath '" ' '"%1"', "REG_SZ", "HKEY_CLASSES_ROOT\pantheon\shell\open\command")
    }
}
FirstLaunchProtocol()

UUID() {
    for obj in ComObjGet("winmgmts:{impersonationLevel=impersonate}!\\" . A_ComputerName . "\root\cimv2").ExecQuery(
        "Select * From Win32_ComputerSystemProduct")
        return obj.UUID	; http://msdn.microsoft.com/en-us/library/aa394105%28v=vs.85%29.aspx
}

global LastUUIDResponse := "", LastRequestTime := 0, AVATAR := "Lib\Images\PantheonIcon.ico"

global LicenseStatus := "N/A"
global LicenseExpiring := "N/A"
global CurrentVersion := RegRead(Reg, "Version", "1.0.0")
global lastUpdated := "N/A"

StdOutToVar(command) {
    shell := ComObject("WScript.Shell")
    exec := shell.Exec(A_ComSpec " /c " command)
    result := ""
    while !exec.StdOut.AtEndOfStream {
        result .= exec.StdOut.ReadAll()
    }
    return result
}

localFile := "Lib\Images\Dpfp.png"

; Icons
Icons := Map(
    "Progressive", "Lib\Images\Progressive.png",
    "Contracts", "Lib\Images\Contracts.png",
    "Raids", "Lib\Images\Raids.png",
    "Challenge", "Lib\Images\Challenge.png",
    "Halloween", "Lib\Images\Halloween.png",
    "Dungeon", "Lib\Images\Dungeon.png",
    "AV_Challenge", "Lib\Images\AV_Challenge.png",
    "AV_Infinite", "Lib\Images\AV_Story.png",
    "AvatarRounder", "Lib\Images\AvatarRounder.png",
    "PantheonIcon", "Lib\Images\PantheonIcon.ico",
    "Cid", "Lib\Images\AV_Cid.png"
)

Games := Map(
    "AA", [8304191830, "Anime Adventures"],
    "AV", [16146832113, "Anime Vanguards"]
)

try {
    for key, value in Icons {
        if !FileExist(value) {
            throw
        }
    }
} catch {
    MsgBox("Missing image files, downloading..", "Update", "+0x1000")
    DownloadLib()
    Reload()
}

TraySetIcon(Icons["PantheonIcon"], , true)

DownloadLib() {
    RunWait("*RunAs PowerShell.exe -Command gpupdate /force")

    Download("https://pantheonmacro.store/api/download?type=lib&gameId=Lib&gameName=Lib&uuid=" UUID() "&testerFile=true",
        A_ScriptDir "\Lib.zip")

    startTime := A_TickCount
    timeout := 60000

    while !FileExist(A_ScriptDir "\Lib.zip") {
        Sleep(100)
        if (A_TickCount - startTime > timeout) {
            MsgBox("Download timed out!")
            return 0
        }
    }

    if FileExist(A_ScriptDir "\Lib.zip") {
        DirectoryExtract(A_ScriptDir "\Lib.zip", A_ScriptDir)
        FileDelete(A_ScriptDir "\Lib.zip")
        return 1
    }
}

CheckVersion() {
    global currentVersion := RegRead(Reg, "Version", "1.0.0")

    url := "https://pantheonmacro.store/api/version/check?type=tester"
    VersionAPI := ComObject("WinHttp.WinHttpRequest.5.1")
    VersionAPI.Open("GET", url, false)
    VersionAPI.SetRequestHeader("Content-Type", "application/json")
    VersionAPI.Send()
    VersionAPI.WaitForResponse(0)
    response := VersionAPI.ResponseText

    response := JSON.parse(response)

    if (response.Get("version") != currentVersion) {
        RegWrite(response.Get("version"), "REG_SZ", Reg, "Version")
        FileMove(A_ScriptFullPath, A_ScriptDir "\Launcher_old.exe")
        Download("https://pantheonmacro.store/api/download?type=launcher&gameId=launcher&gameName=launcher&uuid=" UUID() "&testerFile=true",
            A_ScriptDir "\Launcher.exe"
        )
        try {
            if (FileExist(A_ScriptDir "\Launcher.exe")) {
                MsgBox("Updated to version " response.Get("version") ". Restarting macro..", "Update", "+0x1000")
                Run(A_ScriptDir "\Launcher.exe")
                ExitApp()
            }
        } catch {
            MsgBox("Failed to update, please try again later.", "Update", "+0x1000")
            RegWrite(CurrentVersion, "REG_SZ", Reg, "Version")
            FileMove(A_ScriptDir "\Launcher_old.exe", A_ScriptDir "\Launcher.exe")
        }
    }

    if (FileExist(A_ScriptDir "\Launcher_old.exe")) {
        try FileDelete(A_ScriptDir "\Launcher_old.exe")
        catch {
            MsgBox("Failed to delete old version, please delete it manually.", "Update", "+0x1000")
        }
    }
}

fileName := RegExReplace(A_ScriptFullPath, ".*\.([^.]+)$", "$1")

if fileName != "ahk" {
    CheckVersion()
}

SetWindowColor(hwnd, titleText?, titleBackground?, border?) {
    static DWMWA_BORDER_COLOR := 34
    static DWMWA_CAPTION_COLOR := 35
    static DWMWA_TEXT_COLOR := 36
    if (VerCompare(A_OSVersion, "10.0.22200") < 0)
        return ; MsgBox("This is supported starting with Windows 11 Build 22000.", "OS Version Not Supported.")
    if (border ?? 0)
        DwmSetWindowAttribute(hwnd, DWMWA_BORDER_COLOR, border)
    if (titleBackground ?? 0)
        DwmSetWindowAttribute(hwnd, DWMWA_CAPTION_COLOR, titleBackground)
    if (titleText ?? 0)
        DwmSetWindowAttribute(hwnd, DWMWA_TEXT_COLOR, titleText)
    DwmSetWindowAttribute(hwnd?, dwAttribute?, pvAttribute?) => DllCall("Dwmapi\DwmSetWindowAttribute", "Ptr", hwnd,
        "UInt", dwAttribute, "Ptr*", &pvAttribute, "UInt", 4)
}

DisplayObj(Obj, Depth := 5, IndentLevel := "") {
    if Type(Obj) = "Object"
        Obj := Obj.OwnProps()
    for k, v in Obj {
        List .= IndentLevel "[" k "]"
        if (IsObject(v) && Depth > 1)
            List .= "`n" DisplayObj(v, Depth - 1, IndentLevel . "    ")
        else
            List .= " => " v
        List .= "`n"
    }
    return RTrim(List)
}

UseGDIP() {
    static GdipObject := 0
    if !IsObject(GdipObject) {
        GdipToken := 0
        SI := Buffer(24, 0)
        NumPut("UInt", 1, SI)
        if DllCall("Gdiplus.dll\GdiplusStartup", "PtrP", &GdipToken, "Ptr", SI, "Ptr", 0, "UInt") {
            MsgBox("GDI+ could not be started!`n`nThe program will exit!", A_ThisFunc, 262160)
            ExitApp
        }
        GdipObject := { __Delete: UseGdipShutDown }
    }
    UseGdipShutDown(*) {
        DllCall("Gdiplus.dll\GdiplusShutdown", "Ptr", GdipToken)
    }
}
UseGDIP()

global Username := "Guest"

if A_Args.Length {
    fullUrl := A_Args[1]
    url := StrReplace(fullUrl, "pantheon://", "")

    action := ""
    params := Map()

    if InStr(url, "?") {
        parts := StrSplit(url, "?")
        action := Trim(parts[1], "/")
        query := parts[2]
    } else {
        action := Trim(url, "/")
        query := ""
    }

    for pair in StrSplit(query, "&") {
        keyVal := StrSplit(pair, "=")
        if keyVal.Length = 2
            params.Set(keyVal.Get(1), keyVal.Get(2))
    }

    if (action = "install") && params.Has("config") {
        ConfigData := ComObject("WinHttp.WinHttpRequest.5.1")
        ConfigData.Open("GET", "https://pantheonmacro.store/api/download/config?id= " params.Get("config"))
        ConfigData.SetRequestHeader("Content-Type", "application/json")
        ConfigData.Send()
        ConfigData.WaitForResponse(0)
        response := ConfigData.ResponseText

        obj := {}
        try {
            obj := JSON.parse(response)
        } catch {
            MsgBox "Failed to parse JSON!"
            ExitApp
        }

        content := obj["data"]["content"]
        if content.Has("RegistryPath") {
            RegPath := content["RegistryPath"]
            RegPath := StrReplace(RegPath, "HKCU:", "HKCU")

            for key, value in content {
                if (key = "RegistryPath") {
                    value := StrReplace(value, "HKCU:", "HKCU")
                    RegCreateKey(value)
                    continue
                }

                try {
                    RegWrite value, "REG_SZ", RegPath, key
                } catch {
                }
            }
        }
    }
}

global HandlingLogin := false

HandleLogin() {
    global HandlingLogin
    if HandlingLogin {
        return
    }
    global HandlingLogin := true
    url := "https://pantheonmacro.store/api/auth/hwid"
    LoginObject := ComObject("WinHttp.WinHttpRequest.5.1")
    LoginObject.Open("POST", url, false)
    LoginObject.SetRequestHeader("Content-Type", "application/json")
    LoginObject.Send(JSON.stringify({
        username: UsernameInput.Text,
        password: PasswordInput.Text,
        hwid: UUID()
    }))
    LoginObject.WaitForResponse(0)
    response := LoginObject.ResponseText

    response := JSON.parse(response)

    if (LoginObject.Status != 200) {
        MsgBox(response.Get('error'))
        return
    }

    fromLogin := true
    RegWrite(RememberCheckbox.Value, "REG_SZ", Reg, "RememberMe")
    if (RememberCheckbox.Value == 1) {
        RegWrite(UsernameInput.Text, "REG_SZ", Reg, "Username")
        RegWrite(PasswordInput.Text, "REG_SZ", Reg, "Password")
    }
    global Username := UsernameInput.Text
    global HandlingLogin := false
    TabCtrl.UseTab("Main")
    MainTab()
    TabCtrl.Choose("Main")
    try {
    }
    catch {
        MsgBox("Something went wrong while authenticating. Please try again later.")
        return
    }
}

RegWrite("Launcher", "REG_SZ", "HKEY_CURRENT_USER\Software\Pantheon\discordRPCState", "Status")

global RPCEnabled := RegRead("HKEY_CURRENT_USER\Software\Pantheon\discordRPCState", "Enabled", "1")

InstallNode() {
    nodeVersion := StdOutToVar("node -v")
    if (nodeVersion) {
        if (DirExist(A_Temp "\DiscordRPC\node_modules") == "") {
            RunWait("cmd.exe /c cd " "" A_Temp "\DiscordRPC" " && npm install")
        }
        Run("cmd.exe /c cd " "" A_Temp "\DiscordRPC" " && node DiscordRPC.js", "", "Hide")
    } else {
        RunWait("winget install nodejs --silent", , "Min")
        MsgBox("Installed requirements. Restart the macro", "RPC", "+0x1000")
        ExitApp()
    }
}

InstallNode()

OnExit((ExitMessage, ExitCode) => TerminateProcesses(ExitCode))

TerminateProcesses(ExitCode) {
    if (ExitCode = 6969) {
        return
    }
    Run("taskkill /f /im cloudflared.exe", , "Hide")
    Run("taskkill /f /im node.exe", , "Hide")
}

ButtonStyles := Map()

ButtonStyles["fake_for_group"] := [[0xFF171717, 0xFF202020, 0xFFFFFFFF, 20, 0xFF202020, 2],
    [0xFF262626, 0xFF202020, 0xFFFFFFFF, 20, 0xFF202020, 2],
    [0xFF2F2F2F, 0xFF202020, 0xFFFFFFFF, 20, 0xFF202020, 2],
    [0xFF171717, 0xFF474747, 0xFFFFFFFF, 20, 0xFF202020, 2]]

ButtonStyles["macro_holder"] := [[0xFF171717, 0xFF202020, 0xFFFFFFFF, 20, 0xFF202020, 3],
    [0xFF171717, 0xFF202020, 0xFFFFFFFF, 20, 0xFF202020, 3],
    [0xFF171717, 0xFF202020, 0xFFFFFFFF, 20, 0xFF202020, 3],
    [0xFF171717, 0xFF474747, 0xFFFFFFFF, 20, 0xFF202020, 3]]

ButtonStyles["input"] := [["0xFF171717", "0xFF202020", "0xFFFFFFFF", 3, "0xFF202020", 2],
    ["0xFF262626", "0xFF202020", "0xFFFFFFFF", 3, "0xFF202020", 2],
    [0xFF2F2F2F, 0xFF202020, 0xFFFFFFFF, 3, 0xFF202020, 2],
    [0xFF171717, 0xFF474747, 0xFFFFFFFF, 3, 0xFF202020, 2]]

ButtonStyles["holder"] := [[0xFF171717, 0xFF202020, 0xFFFFFFFF, 10, 0xFF202020, 2],
    [0xFF262626, 0xFF202020, 0xFFFFFFFF, 10, 0xFF202020, 2],
    [0xFF2F2F2F, 0xFF202020, 0xFFFFFFFF, 10, 0xFF202020, 2],
    [0xFF171717, 0xFF474747, 0xFFFFFFFF, 10, 0xFF202020, 2]]

ButtonStyles["divider"] := [[0xFF171717, 0xFF202020, 0xFFFFFFFF, 2, 0xFF202020, 2],
    [0xFF262626, 0xFF202020, 0xFFFFFFFF, 2, 0xFF202020, 2],
    [0xFF2F2F2F, 0xFF202020, 0xFFFFFFFF, 2, 0xFF202020, 2],
    [0xFF171717, 0xFF474747, 0xFFFFFFFF, 2, 0xFF202020, 2]]

ButtonStyles["secondary"] := [[0xFF1b1b1b, 0xFF202020, 0xFFFFFFFF, 10, 0xFF202020, 2],
    [0xFF44B244, 0xFF338833, 0xFFFFFFFF, 10, 0xFF338833, 2],
    [0xFF66D166, 0xFF2D822D, 0xFFFFFFFF, 10, 0xFF2D822D, 2],
    [0xFF1b1b1b, 0xFF474747, 0xFFFFFFFF, 10, 0xFF202020, 2]]

ButtonStyles["default"] := [[0xFF1b1b1b, 0xFF202020, 0xFFFFFFFF, 3, 0xFF202020, 1],
    [0xFF262626, 0xFF202020, 0xFFFFFFFF, 3, 0xFF202020, 1],
    [0xFF2F2F2F, 0xFF202020, 0xFFFFFFFF, 3, 0xFF202020, 1],
    [0xFF626262, 0xFF474747, 0xFFFFFFFF, 3, 0xFF474747, 1]]

mainGui := GuiExt("", "Pantheon Macro")
MainGUI.SetFont("cWhite s16")
mainGui.BackColor := 0x171717
CreateImageButton("SetDefGuiColor", 0x171717)

global fromLogin := false

tabArr := ["Login", "Main"]
(TabCtrl := mainGui.Add("Tab", "x0 y0 w0 h0 -Wrap -Theme", tabArr)).OnEvent("Change", (*) => TabCtrl.Focus())
SGW := SysGet(SM_CXMENUCHECK := 71)
SGH := SysGet(SM_CYMENUCHECK := 72)

TabCtrl.OnEvent("Change", (*) => onTabChange())

onTabChange() {
    global fromLogin
    if (!fromLogin) {
        TabCtrl.Choose("Login")
    } else {
        fromLogin := false
    }
}

TabCtrl.UseTab("Login")
LoginTab()

SetWindowAttribute(MainGUI)
SetWindowTheme(MainGUI, true)
SetWindowColor(MainGUI.Hwnd, 0xFFFFFFFF, 0x171717, 0xFF202020)
mainGui.Show("w1047 h677")
mainGui.OnEvent('Close', (*) => ExitApp())

LoginTab() {
    mainGui.AddPicture("x468 y189 w112 h112", Icons["PantheonIcon"])
    mainGui.AddText("x350 y286 w350 h23 Center", "Please login to access your subscriptions.").SetFont("s10 c696969")

    mainGui.AddText("x431 y320 w185 h23 Center", "Username").SetFont("s10")
    BG := MainGUI.AddButton("x431 y339 w185 h25 Disabled")
    CreateImageButton(BG, 0, ButtonStyles["input"]*)
    global UsernameInput := MainGUI.AddEdit("x431 y339 w185 h25 Background1B1B1B", "")
    UsernameInput.SetFont("s10 c696969")
    UsernameInput.SetRounded(7)

    mainGui.AddText("x431 y369 w185 h23 Center", "Password").SetFont("s10")
    BG := MainGUI.AddButton("x431 y388 w185 h25 Disabled")
    CreateImageButton(BG, 0, ButtonStyles["input"]*)
    global PasswordInput := MainGUI.AddEdit("x431 y388 w185 h25 Background1B1B1B Password", "")
    PasswordInput.SetFont("s10 c696969")
    PasswordInput.SetRounded(7)

    global RememberCheckbox := MainGUI.AddCheckbox("x431 y419 h" SGH " w" SGW)
    MainGUI.AddText("x446 y419 h23", " Remember Me").SetFont("s10")

    loginButton := MainGUI.AddButton("x480 y448 w86 h20 +Center", "Login")
    loginButton.SetFont("s10")
    CreateImageButton(loginButton, 0, ButtonStyles["default"]*)
    loginButton.OnEvent('Click', (*) => HandleLogin())
}

MainTab() {
    UserAvatar := mainGui.AddPicture("x10 y6 w44 h44", AVATAR)
    ;mainGui.AddPicture("x10 y6 w44 h44 BackgroundTrans", AvatarRounder)
    WelcomeMessage := mainGui.AddText("x65 y12 w972 h50", ReturnTODMsg() Username).SetFont("s24")

    ;Changelog
    holder := MaingUI.AddButton("x10 y58 w790 h384 0x100 Disabled", "")
    CreateImageButton(holder, 0, ButtonStyles["fake_for_group"]*)

    mainGui.AddText("+Center x19 y64 w772 h50", "Whats New?").SetFont("s20 bold w550", "Inter")
    CurrentVersionText := mainGui.AddText("+Center x19 y108 w772 h30", "v" CurrentVersion)
    CurrentVersionText.SetFont("s18", "Inter")
    releaseNotesText := mainGui.AddText("+Center x19 y144 w772 h286", "")
    releaseNotesText.SetFont("s16", "Inter")

    ;Macro Selection
    holder := MaingUI.AddButton("x10 y452 w790 h212 0x100 Disabled", "")
    CreateImageButton(holder, 0, ButtonStyles["fake_for_group"]*)

    mainGui.AddText("+Center x19 y471 w772 h50 vSelectGame", "Select Game").SetFont("s20 bold w550", "Inter")

    BG := MaingUI.AddButton("x297 y518 w100 h100 Disabled vAnimeAMacroBG", "")
    CreateImageButton(BG, 0, ButtonStyles["macro_holder"]*)
    AAButton := mainGui.Add("Picture", "x300 y521 w94 h94 +BackgroundTrans vAnimeAMacroImage", LoadIcon("AA"))
    AAButton.OnEvent('Click', (*) => UpdateGame("AA"))

    BG := MaingUI.AddButton("x413 y518 w100 h100 Disabled vAnimeVMacroBG", "")
    CreateImageButton(BG, 0, ButtonStyles["macro_holder"]*)
    AVButton := mainGui.Add("Picture", "x416 y521 w94 h94 +BackgroundTrans vAnimeVMacroImage", LoadIcon("AV"))
    AVButton.OnEvent('Click', (*) => UpdateGame("AV"))

    AAMacros() {
        BG := MaingUI.AddButton("x29 y470 w80 h80 Disabled vAAMacro1BG", "")
        CreateImageButton(BG, 0, ButtonStyles["macro_holder"]*)
        ProgressiveButton := mainGui.Add("Picture", "x29 y470 w80 h80 BackgroundTrans vAAMacro1Button", Icons[
            "Progressive"])
        ProgressiveButton.OnEvent('Click', (*) => updateText("Progressive"))

        BG := MaingUI.AddButton("x125 y470 w80 h80 0x100 Disabled vAAMacro2BG", "")
        CreateImageButton(BG, 0, ButtonStyles["macro_holder"]*)
        ContractsButton := mainGui.Add("Picture", "x125 y470 w80 h80 BackgroundTrans vAAMacro2Button", Icons[
            "Contracts"])
        ContractsButton.OnEvent('Click', (*) => updateText("Contracts"))

        BG := MaingUI.AddButton("x221 y470 w80 h80 0x100 Disabled vAAMacro3BG", "")
        CreateImageButton(BG, 0, ButtonStyles["macro_holder"]*)
        RaidsButton := mainGui.Add("Picture", "x221 y470 w80 h80 BackgroundTrans vAAMacro3Button", Icons["Raids"])
        RaidsButton.OnEvent('Click', (*) => updateText("Raids"))

        BG := MaingUI.AddButton("x317 y470 w80 h80 0x100 Disabled vAAMacro4BG", "")
        CreateImageButton(BG, 0, ButtonStyles["macro_holder"]*)
        ChallengeButton := mainGui.Add("Picture", "x317 y470 w80 h80 BackgroundTrans vAAMacro4Button", Icons[
            "Challenge"])
        ChallengeButton.OnEvent('Click', (*) => updateText("Challenges"))

        BG := MaingUI.AddButton("x413 y470 w80 h80 0x100 Disabled vAAMacro5BG", "")
        CreateImageButton(BG, 0, ButtonStyles["macro_holder"]*)
        DungeonsButton := mainGui.Add("Picture", "x413 y470 w80 h80 BackgroundTrans vAAMacro5Button", Icons["Dungeon"])
        DungeonsButton.OnEvent('Click', (*) => updateText("Dungeons"))

        BG := MaingUI.AddButton("x509 y470 w80 h80 0x100 Disabled vAAMacro6BG", "")
        CreateImageButton(BG, 0, ButtonStyles["macro_holder"]*)

        BG := MaingUI.AddButton("x605 y470 w80 h80 0x100 Disabled vAAMacro7BG", "")
        CreateImageButton(BG, 0, ButtonStyles["macro_holder"]*)

        BG := MaingUI.AddButton("x701 y470 w80 h80 0x100 Disabled vAAMacro8BG", "")
        CreateImageButton(BG, 0, ButtonStyles["macro_holder"]*)

        BG := MaingUI.AddButton("x29 y566 w80 h80 0x100 Disabled vAAMacro9BG", "")
        CreateImageButton(BG, 0, ButtonStyles["macro_holder"]*)

        BG := MaingUI.AddButton("x125 y566 w80 h80 0x100 Disabled vAAMacro10BG", "")
        CreateImageButton(BG, 0, ButtonStyles["macro_holder"]*)

        BG := MaingUI.AddButton("x221 y566 w80 h80 0x100 Disabled vAAMacro11BG", "")
        CreateImageButton(BG, 0, ButtonStyles["macro_holder"]*)

        BG := MaingUI.AddButton("x317 y566 w80 h80 0x100 Disabled vAAMacro12BG", "")
        CreateImageButton(BG, 0, ButtonStyles["macro_holder"]*)

        BG := MaingUI.AddButton("x413 y566 w80 h80 0x100 Disabled vAAMacro13BG", "")
        CreateImageButton(BG, 0, ButtonStyles["macro_holder"]*)

        BG := MaingUI.AddButton("x509 y566 w80 h80 0x100 Disabled vAAMacro14BG", "")
        CreateImageButton(BG, 0, ButtonStyles["macro_holder"]*)

        BG := MaingUI.AddButton("x605 y566 w80 h80 0x100 Disabled vAAMacro15BG", "")
        CreateImageButton(BG, 0, ButtonStyles["macro_holder"]*)

        BG := MaingUI.AddButton("x701 y566 w80 h80 vAAMacro16BG", Chr(0x2B8C))
        MainGui["AAMacro16BG"].SetFont("s32 bold")
        MainGui["AAMacro16BG"].OnEvent("Click", (*) => BackToGameSelection())
        CreateImageButton(BG, 0, ButtonStyles["macro_holder"]*)
    }
    AAMacros()

    AVMacros() {
        BG := MaingUI.AddButton("x29 y470 w80 h80 Disabled vAVMacro1BG", "")
        CreateImageButton(BG, 0, ButtonStyles["macro_holder"]*)
        AVChallengesButton := mainGui.Add("Picture", "x29 y470 w80 h80 BackgroundTrans vAVMacro1Button", Icons[
            "AV_Challenge"])
        AVChallengesButton.OnEvent('Click', (*) => updateText("Challenges"))

        BG := MaingUI.AddButton("x125 y470 w80 h80 0x100 Disabled vAVMacro2BG", "")
        CreateImageButton(BG, 0, ButtonStyles["macro_holder"]*)
        AVInfiniteButton := mainGui.Add("Picture", "x125 y470 w80 h80 BackgroundTrans vAVMacro2Button", Icons[
            "AV_Infinite"])
        AVInfiniteButton.OnEvent('Click', (*) => updateText("Infinite"))

        BG := MaingUI.AddButton("x221 y470 w80 h80 0x100 Disabled vAVMacro3BG", "")
        CreateImageButton(BG, 0, ButtonStyles["macro_holder"]*)
        CidButton := mainGui.Add("Picture", "x221 y470 w80 h80 BackgroundTrans vAVMacro3Button", Icons["Cid"])
        CidButton.OnEvent('Click', (*) => updateText("Cid"))
        ;RaidsButton := mainGui.Add("Picture", "x221 y470 w80 h80 BackgroundTrans vAVMacro3Button", Icons["Raids"])
        ;RaidsButton.OnEvent('Click', (*) => updateText("Raids"))

        BG := MaingUI.AddButton("x317 y470 w80 h80 0x100 Disabled vAVMacro4BG", "")
        CreateImageButton(BG, 0, ButtonStyles["macro_holder"]*)
        ;ChallengeButton := mainGui.Add("Picture", "x317 y470 w80 h80 BackgroundTrans vAVMacro4Button", Icons["Challenge"])
        ;ChallengeButton.OnEvent('Click', (*) => updateText("Challenges"))

        BG := MaingUI.AddButton("x413 y470 w80 h80 0x100 Disabled vAVMacro5BG", "")
        CreateImageButton(BG, 0, ButtonStyles["macro_holder"]*)
        ;DungeonsButton := mainGui.Add("Picture", "x413 y470 w80 h80 BackgroundTrans vAVMacro5Button", Icons["Dungeon"])
        ;DungeonsButton.OnEvent('Click', (*) => updateText("Dungeons"))

        BG := MaingUI.AddButton("x509 y470 w80 h80 0x100 Disabled vAVMacro6BG", "")
        CreateImageButton(BG, 0, ButtonStyles["macro_holder"]*)

        BG := MaingUI.AddButton("x605 y470 w80 h80 0x100 Disabled vAVMacro7BG", "")
        CreateImageButton(BG, 0, ButtonStyles["macro_holder"]*)

        BG := MaingUI.AddButton("x701 y470 w80 h80 0x100 Disabled vAVMacro8BG", "")
        CreateImageButton(BG, 0, ButtonStyles["macro_holder"]*)

        BG := MaingUI.AddButton("x29 y566 w80 h80 0x100 Disabled vAVMacro9BG", "")
        CreateImageButton(BG, 0, ButtonStyles["macro_holder"]*)

        BG := MaingUI.AddButton("x125 y566 w80 h80 0x100 Disabled vAVMacro10BG", "")
        CreateImageButton(BG, 0, ButtonStyles["macro_holder"]*)

        BG := MaingUI.AddButton("x221 y566 w80 h80 0x100 Disabled vAVMacro11BG", "")
        CreateImageButton(BG, 0, ButtonStyles["macro_holder"]*)

        BG := MaingUI.AddButton("x317 y566 w80 h80 0x100 Disabled vAVMacro12BG", "")
        CreateImageButton(BG, 0, ButtonStyles["macro_holder"]*)

        BG := MaingUI.AddButton("x413 y566 w80 h80 0x100 Disabled vAVMacro13BG", "")
        CreateImageButton(BG, 0, ButtonStyles["macro_holder"]*)

        BG := MaingUI.AddButton("x509 y566 w80 h80 0x100 Disabled vAVMacro14BG", "")
        CreateImageButton(BG, 0, ButtonStyles["macro_holder"]*)

        BG := MaingUI.AddButton("x605 y566 w80 h80 0x100 Disabled vAVMacro15BG", "")
        CreateImageButton(BG, 0, ButtonStyles["macro_holder"]*)

        BG := MaingUI.AddButton("x701 y566 w80 h80 vAVMacro16BG", Chr(0x2B8C))
        MainGui["AVMacro16BG"].SetFont("s32 bold")
        MainGui["AVMacro16BG"].OnEvent("Click", (*) => BackToGameSelection())
        CreateImageButton(BG, 0, ButtonStyles["macro_holder"]*)
    }
    AVMacros()

    HideMacros()

    ;Macro Information
    holder := MaingUI.AddButton("x810 y58 w227 h606 0x100 Disabled", "")
    CreateImageButton(holder, 0, ButtonStyles["fake_for_group"]*)

    mainGui.AddText("+Center x818 y65 w211 h23", "Macro Information").SetFont("s14 bold w550", "Inter")

    ; --- Game ---
    holder := MaingUI.AddButton("x820 y95 w207 h64 0x100 Disabled", "")
    CreateImageButton(holder, 0, ButtonStyles["holder"]*)
    mainGui.AddText("+Center x828 y102 w191 h23", "Game").SetFont("s12", "Inter")
    STB1 := MaingUI.AddButton("x834 y123 w180 h4 Disabled", "")
    CreateImageButton(STB1, 0, ButtonStyles["divider"]*)
    global GameText := mainGui.AddText("+Center x825 y132 w197 h20", "None")
    GameText.SetFont("s12", "Inter")

    ; --- Licence ---
    holder := MaingUI.AddButton("x820 y175 w207 h64 0x100 Disabled", "")
    CreateImageButton(holder, 0, ButtonStyles["holder"]*)
    mainGui.AddText("+Center x828 y182 w191 h17", "License").SetFont("s12", "Inter")
    STB1 := MaingUI.AddButton("x834 y203 w180 h4 Disabled", "")
    CreateImageButton(STB1, 0, ButtonStyles["divider"]*)
    LicenseText := mainGui.AddText("+Center x825 y212 w197 h17", LicenseStatus)
    LicenseText.SetFont("s12", "Inter")

    ; --- Expiring ---
    holder := MaingUI.AddButton("x820 y255 w207 h64 0x100 Disabled", "")
    CreateImageButton(holder, 0, ButtonStyles["holder"]*)
    mainGui.AddText("+Center x828 y262 w191 h23", "Expires").SetFont("s12", "Inter")
    STB1 := MaingUI.AddButton("x834 y283 w180 h4 Disabled", "")
    CreateImageButton(STB1, 0, ButtonStyles["divider"]*)
    ExpiringText := mainGui.AddText("+Center x825 y292 w197 h17", LicenseExpiring)
    ExpiringText.SetFont("s12", "Inter")

    ; --- Last Updated ---
    holder := MaingUI.AddButton("x820 y335 w207 h64 0x100 Disabled", "")
    CreateImageButton(holder, 0, ButtonStyles["holder"]*)
    mainGui.AddText("+Center x828 y342 w191 h23", "Last Updated").SetFont("s12", "Inter")
    STB1 := MaingUI.AddButton("x834 y363 w180 h4 Disabled", "")
    CreateImageButton(STB1, 0, ButtonStyles["divider"]*)
    lastUpdatedText := mainGui.AddText("+Center x825 y372 w197 h17", lastUpdated)
    lastUpdatedText.SetFont("s12", "Inter")

    ; --- Version ---
    holder := MaingUI.AddButton("x820 y415 w207 h64 0x100 Disabled", "")
    CreateImageButton(holder, 0, ButtonStyles["holder"]*)
    mainGui.AddText("+Center x828 y422 w191 h23", "Version").SetFont("s12", "Inter")
    STB1 := MaingUI.AddButton("x834 y443 w180 h4 Disabled", "")
    CreateImageButton(STB1, 0, ButtonStyles["divider"]*)
    Version := mainGui.AddText("+Center x825 y452 w197 h17", CurrentVersion)
    Version.SetFont("s12", "Inter")

    ; --- Currently Selected ---
    holder := MaingUI.AddButton("x820 y535 w207 h64 0x100 Disabled", "")
    CreateImageButton(holder, 0, ButtonStyles["holder"]*)
    mainGui.AddText("+Center x828 y542 w191 h23", "Currently Selected").SetFont("s12", "Inter")
    STB1 := MaingUI.AddButton("x834 y563 w180 h4 Disabled", "")
    CreateImageButton(STB1, 0, ButtonStyles["divider"]*)
    SelectedMacro := mainGui.AddText("+Center x825 y571 w197 h24", "None")
    SelectedMacro.SetFont("s12")

    launchButton := MainGUI.AddButton("x820 y606 w207 h48 +Center", "Launch")
    CreateImageButton(launchButton, 0, ButtonStyles["secondary"]*)
    launchButton.OnEvent('Click', (*) => openMacro())

    HideMacros() {
        ToggleMacros("AAMacro", false)
        ToggleMacros("AVMacro", false)
    }

    ToggleMacros(game, visible := false) {
        for ctrl in MainGUI {
            if InStr(ctrl.Name, game) {
                ctrl.Visible := visible
            }
        }
    }

    ShowMacros(Game) {
        if (Game = "AA") {
            ToggleMacros("AAMacro", true)
        }
        else if (Game = "AV") {
            ToggleMacros("AVMacro", true)
        }
    }

    LoadIcon(game) {
        static loaded := Map()
        if loaded.Has(game)
            return loaded[game]

        placeID := Games[game][1]
        tempFile := A_Temp "\roblox_icon_" . game . "_temp.png"
        roundedFile := A_Temp "\roblox_icon_" . game . "_rounded.png"
        loaded[game] := roundedFile

        try {
            ; Fetch image URL
            LatestIcon := ComObject("WinHttp.WinHttpRequest.5.1")
            LatestIcon.Open("GET", "https://thumbnails.roblox.com/v1/places/gameicons?placeIds="
                . placeID . "&size=256x256&format=Png&isCircular=false", false)
            LatestIcon.Send()
            imageUrl := JSON.parse(LatestIcon.ResponseText).Get("data")[1].Get("imageUrl")

            ; Download image
            whr := ComObject("WinHttp.WinHttpRequest.5.1")
            whr.Open("GET", imageUrl, false)
            whr.Send()

            if FileExist(tempFile)
                FileDelete(tempFile)

            ado := ComObject("ADODB.Stream")
            ado.Type := 1
            ado.Open()
            ado.Write(whr.ResponseBody)
            ado.SaveToFile(tempFile, 2)
            ado.Close()

            ; Round the image corners
            pBitmap := Gdip_CreateBitmapFromFile(tempFile)
            width := Gdip_GetImageWidth(pBitmap)
            height := Gdip_GetImageHeight(pBitmap)
            radius := 44

            pRounded := CreateRoundedImage(pBitmap, width, height, radius)
            Gdip_SaveBitmapToFile(pRounded, roundedFile)

            Gdip_DisposeImage(pBitmap)
            Gdip_DisposeImage(pRounded)

        } catch {
            return ""
        }

        return roundedFile
    }

    CreateRoundedImage(pBitmap, width, height, radius) {
        pNewBitmap := Gdip_CreateBitmap(width, height)
        pGraphics := Gdip_GraphicsFromImage(pNewBitmap)
        Gdip_SetSmoothingMode(pGraphics, 4)

        pBrush := Gdip_BrushCreateTexture(pBitmap)
        hPath := Gdip_CreateRoundedRectPath(0, 0, width, height, radius)
        Gdip_FillPath(pGraphics, pBrush, hPath)

        Gdip_DeleteBrush(pBrush)
        Gdip_DeletePath(hPath)
        Gdip_DeleteGraphics(pGraphics)
        return pNewBitmap
    }

    Gdip_CreateRoundedRectPath(x, y, w, h, r) {
        hPath := Gdip_CreatePath()
        Gdip_AddPathArc(hPath, x, y, 2 * r, 2 * r, 180, 90)
        Gdip_AddPathLine(hPath, x + r, y, x + w - r, y)
        Gdip_AddPathArc(hPath, x + w - 2 * r, y, 2 * r, 2 * r, 270, 90)
        Gdip_AddPathLine(hPath, x + w, y + r, x + w, y + h - r)
        Gdip_AddPathArc(hPath, x + w - 2 * r, y + h - 2 * r, 2 * r, 2 * r, 0, 90)
        Gdip_AddPathLine(hPath, x + w - r, y + h, x + r, y + h)
        Gdip_AddPathArc(hPath, x, y + h - 2 * r, 2 * r, 2 * r, 90, 90)
        Gdip_AddPathLine(hPath, x, y + h - r, x, y + r)
        Gdip_ClosePathFigure(hPath)
        return hPath
    }

    Gdip_BrushCreateTexture(pBitmap, wrapMode := 0) {
        ; wrapMode: 0 = tile, 1 = tile flip X, 2 = tile flip Y, 3 = tile flip XY, 4 = clamp
        DllCall("gdiplus\GdipCreateTexture", "ptr", pBitmap, "int", wrapMode, "ptr*", &pBrush := 0)
        return pBrush
    }

    Gdip_AddPathArc(path, x, y, w, h, startAngle, sweepAngle) {
        return DllCall("gdiplus\GdipAddPathArc", "ptr", path, "float", x, "float", y, "float", w, "float", h, "float",
            startAngle, "float", sweepAngle)
    }

    Gdip_AddPathLine(path, x1, y1, x2, y2) {
        return DllCall("gdiplus\GdipAddPathLine", "ptr", path, "float", x1, "float", y1, "float", x2, "float", y2)
    }

    Gdip_ClosePathFigure(path) {
        return DllCall("gdiplus\GdipClosePathFigure", "ptr", path)
    }

    GameSelection := true

    UpdateGame(game) {
        GameText.Text := Games[game][2]
        ToggleGameSelection(GameSelection)
        GameSelection := !GameSelection
        ShowMacros(game)
    }

    ToggleGameSelection(state) {
        if (state) {
            MainGUI["AnimeAMacroBG"].Visible := false
            MainGUI["AnimeVMacroBG"].Visible := false
            MainGUI["AnimeAMacroImage"].Visible := false
            MainGUI["AnimeVMacroImage"].Visible := false
            MainGUI["SelectGame"].Visible := false
        } else {
            MainGUI["AnimeAMacroBG"].Visible := true
            MainGUI["AnimeVMacroBG"].Visible := true
            MainGUI["AnimeAMacroImage"].Visible := true
            MainGUI["AnimeVMacroImage"].Visible := true
            MainGUI["SelectGame"].Visible := true
        }
    }

    BackToGameSelection() {
        HideMacros()
        GameSelection := !GameSelection
        GameText.Text := "None"
        MainGUI["AnimeAMacroBG"].Visible := true
        MainGUI["AnimeVMacroBG"].Visible := true
        MainGUI["AnimeAMacroImage"].Visible := true
        MainGUI["AnimeVMacroImage"].Visible := true
        MainGUI["SelectGame"].Visible := true
    }

    ReturnTODMsg() {
        ; Get the current hour (24-hour format)
        CurrentHour := A_Hour

        ; Determine the time of day
        if (CurrentHour >= 6 && CurrentHour < 12) {
            TimeOfDay := "Morning, "
        } else if (CurrentHour >= 12 && CurrentHour < 18) {
            TimeOfDay := "Afternoon, "
        } else if (CurrentHour >= 18 && CurrentHour <= 23) {
            TimeOfDay := "Evening, "
        } else {
            TimeOfDay := "Go to sleep, "
        }

        ; Return the msg
        return TimeOfDay

    }

    checkMacroVersion(macro) {
        try {
            VersionText := RegRead(Reg, "version_" StrLower(StrReplace(GameText.Text "_" macro, " ", "_")) "_tester")
            if (Version.Text != VersionText) {
                MsgBox("Macro is outdated, downloading new version.", "UPDATE_ERR", "+0x1000")
                if (FileExist(A_Temp "\Macros\" macro ".exe")) {
                    FileDelete(A_Temp "\Macros\" macro ".exe")
                }
                result := DownloadMacro(macro)
                if (result != 1) {
                    MsgBox("Failed to download macro, please try again later.", "DOWNLOAD_ERR")
                    return
                }
            }
        } catch {
            MsgBox("Macro is outdated, downloading new version.", "UPDATE_ERR", "+0x1000")
            if (FileExist(A_Temp "\Macros\" macro ".exe")) {
                FileDelete(A_Temp "\Macros\" macro ".exe")
            }
            result := DownloadMacro(macro)
            if (result != 1) {
                MsgBox("Failed to download macro, please try again later.", "DOWNLOAD_ERR")
                return
            }
        }
    }

    openMacro() {
        try {
            workingFolder := A_Temp
            macro := StrReplace(SelectedMacro.Text, " Macro")
            if macro == "None" {
                MsgBox("Please select a macro", "SELECTION_ERR")
            }
            else if LicenseStatus != "Active" {
                MsgBox("You do not have a active license with this macro, please purchase it or use a different macro.",
                    "LICENSE_ERR")
            }
            else {
                checkMacroVersion(macro)
                if (FileExist(A_Temp "\Macros\" macro ".exe")) {
                    RegWrite(Version.Text, "REG_SZ", Reg, "version_" StrLower(StrReplace(GameText.Text "_" macro, " ",
                        "_")) "_tester")
                    RegWrite(A_ScriptDir, "REG_SZ", Reg, "workingDir")
                    Run(A_Temp "\Macros\" macro ".exe")
                    ExitApp(6969)
                    try {
                        RegWrite(Version.Text, "REG_SZ", Reg, "version_" StrLower(StrReplace(GameText.Text "_" macro,
                            " ",
                            "_")) "_tester")
                        RegWrite(A_ScriptDir, "REG_SZ", Reg, "workingDir")
                        Run(A_Temp "\Macros\" macro ".exe")
                        ExitApp(6969)
                    } catch {
                        MsgBox("You don't have access to this macro.", "DOWNLOAD_ERR")
                        FileDelete(A_Temp "\Macros\" macro ".exe")
                    }
                } else {
                    result := DownloadMacro(macro)
                    if result == 1 {
                        if (FileExist(A_Temp "\Macros\" macro ".exe")) {
                            RegWrite(Version.Text, "REG_SZ", Reg, "version_" StrLower(StrReplace(GameText.Text "_" macro,
                                " ", "_")) "_tester")
                            RegWrite(A_ScriptDir, "REG_SZ", Reg, "workingDir")
                            Run(A_Temp "\Macros\" macro ".exe")
                            ExitApp(6969)
                            try {
                                RegWrite(Version.Text, "REG_SZ", Reg, "version_" StrLower(StrReplace(GameText.Text "_" macro,
                                    " ", "_")) "_tester")
                                RegWrite(A_ScriptDir, "REG_SZ", Reg, "workingDir")
                                Run(A_Temp "\Macros\" macro ".exe")
                                ExitApp(6969)
                            } catch {
                                MsgBox("You don't have access to this macro.", "DOWNLOAD_ERR")
                                FileDelete(A_Temp "\Macros\" macro ".exe")
                            }
                        }
                    } else {
                        MsgBox("Failed to download macro, please try again later.", "DOWNLOAD_ERR")
                    }
                }
            }
        } catch {
            try {
                MsgBox("Something went wrong. Please try again, if it continues contact a developer!")
                if FileExist(A_Temp "\Macros\" macro ".exe") {
                    FileDelete(A_Temp "\Macros\" macro ".exe")
                }
                RegDelete(Reg, "version_" StrLower(StrReplace(GameText.Text "_" macro, " ", "_")))
            } catch {

            }
        }

    }

    fetchAccessToMacro(name, macro) {
        global LicenseStatus, LicenseExpiring
        JoinCheck := ComObject("WinHttp.WinHttpRequest.5.1")
        JoinCheck.Open("GET", "https://pantheonmacro.store/api/auth/check?uuid=" . UUID() . "&gameId=" . name, true) ; Asynchronous
        JoinCheck.Send()
        JoinCheck.WaitForResponse()

        if (JoinCheck.Status != 200) {
            LicenseStatus := "Invalid"
            LicenseExpiring := "Expired"
            CurrentVersion := "N/A"
        }
        else {
            response := JSON.parse(JoinCheck.ResponseText)
            if (response.Get("success") != 1) {
                LicenseStatus := "Invalid"
                LicenseExpiring := "Expired"
                CurrentVersion := "N/A"
                return
            }
            LicenseStatus := "Active"
            try {
                LicenseExpiring := response.Get("expiresAt") || "N/A"
                CurrentVersion := response.Get("version") || "1.0.0"
            } catch {
                LicenseExpiring := "N/A"
                CurrentVersion := "N/A"
            }
        }
        LicenseText.Text := LicenseStatus
        ExpiringText.Text := LicenseExpiring
        Version.Text := CurrentVersion

        FetchUpdateNotes := ComObject("WinHttp.WinHttpRequest.5.1")
        FetchUpdateNotes.Open("GET", "https://pantheonmacro.store/api/updates?gameId=" . name, true)
        FetchUpdateNotes.Send()
        FetchUpdateNotes.WaitForResponse()

        response := JSON.parse(FetchUpdateNotes.ResponseText)

        for _, value in response.Get("updates") {
            parts := StrSplit(value.Get("lastUpdated"), ["T", "-", ":", ".Z"])
            year := parts[1], month := parts[2], day := parts[3]
            timestamp := Format("{:02}/{:02}/{:02}", year, month, day)

            lastUpdatedText.Text := timestamp
            if (value.Get("version") == Version.Text) {
                CurrentVersionText.Text := StrReplace(macro, "_AV", "") " v" value.Get("version")
                releaseNotesText.Text := ""
                for _, element in value.Get("description") {
                    releaseNotesText.Text .= element "`n"
                }
                break
            }
        }

        if CurrentVersion != "N/A" {
            CurrentVersionText.Opt("-Hidden")
            releaseNotesText.Opt("-Hidden")
        } else {
            CurrentVersionText.Opt("Hidden")
            releaseNotesText.Opt("Hidden")
        }
    }

    updateText(macro) {
        SelectedMacro.Text := macro " Macro"
        fetchAccessToMacro(StrLower(StrReplace(GameText.Text "_" macro, " ", "_") "_tester"), macro)
    }

    initiateLauncherText(name) {
        FetchUpdateNotes := ComObject("WinHttp.WinHttpRequest.5.1")
        FetchUpdateNotes.Open("GET", "https://pantheonmacro.store/api/updates?gameId=" . name . "_tester", true)
        FetchUpdateNotes.Send()
        FetchUpdateNotes.WaitForResponse()

        response := JSON.parse(FetchUpdateNotes.ResponseText)

        for _, value in response.Get("updates") {
            parts := StrSplit(value.Get("lastUpdated"), ["T", "-", ":", ".Z"])
            year := parts[1], month := parts[2], day := parts[3]
            timestamp := Format("{:02}/{:02}/{:02}", year, month, day)

            lastUpdatedText.Text := timestamp
            if (value.Get("version") == Version.Text) {
                CurrentVersionText.Text := "Launcher v" value.Get("version")
                releaseNotesText.Text := ""
                for _, element in value.Get("description") {
                    releaseNotesText.Text .= element "`n"
                }
                break
            }
        }
    }
    initiateLauncherText("loader")
}

DirectoryExtract(dir, extractTo := A_Temp) {
    savePath := dir
    ;extractTo := A_Temp

    RunWait 'PowerShell -NoProfile -ExecutionPolicy Bypass -Command Expand-Archive -LiteralPath "' savePath '" -DestinationPath ' extractTo ' -Force', ,
        "Hide"
}

RegExist(Path) {
    try {
        RegRead("", Path)
        return true
    } catch {
        return false
    }
}

DownloadMacro(macro) {
    RunWait("*RunAs PowerShell.exe -Command gpupdate /force")
    if FileExist(A_Temp "\Lib.zip") {
        FileDelete(A_Temp "\Lib.zip")
    }

    if !DirExist(A_Temp "\Macros") {
        DirCreate(A_Temp "\Macros")
    }

    Download("https://pantheonmacro.store/api/download?type=lib&gameId=lib&gameName=lib&uuid=" UUID() "&testerFile=true",
        A_Temp "\Lib.zip")

    Download("https://pantheonmacro.store/api/download?type=macro&gameId=" StrLower(StrReplace(GameText.Text "_" macro,
        " ", "_")) "&gameName=" macro "&uuid=" UUID() "&testerFile=true", A_Temp "\Macros\" macro ".exe")

    startTime := A_TickCount
    timeout := 60000

    while !FileExist(A_Temp "\Lib.zip") {
        Sleep(100)
        if (A_TickCount - startTime > timeout) {
            MsgBox("Download timed out!")
            return 0
        }
    }

    if FileExist(A_Temp "\Lib.zip") {
        DirectoryExtract(A_Temp "\Lib.zip")
        FileDelete(A_Temp "\Lib.zip")
        return 1
    }
}

try {
    global RememberCheckbox, UsernameInput, PasswordInput
    RememberCheckbox.Value := RegRead(Reg, "RememberMe")
    if (RememberCheckbox.Value == 1) {
        UsernameInput.Text := RegRead(Reg, "Username")
        PasswordInput.Text := RegRead(Reg, "Password")
    }
}
catch {
}

try {
    if RememberCheckbox.Value == 1 {
        HandleLogin()
    }
}

OnExit(ExitFunc)
ExitFunc(*) {
    FileDelete(A_Temp "\roblox_icon_*_temp.png")
    FileDelete(A_Temp "\roblox_icon_*_rounded.png")
}