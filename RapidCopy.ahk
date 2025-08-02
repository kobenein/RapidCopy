; TODO
; 功能: 選擇性 在上或左
; 功能: 支援文件換行符號


#Requires AutoHotkey v2.0
#SingleInstance Force

; --- 全域設定 ---
CoordMode "Mouse", "Screen"

; --- 全域變數 ---
global isExpanded := false
global fontSize := 14
global ZoomFactor := GetZoomFactor()
global collapsedHeight := 6, expandedHeight := 800
global collapsedWidth := 0, collapsedX := 0
global expandedWidth := 0, expandedX := 0
global guiY := 0
global myGui, exitBtn, contentListView
global g_lineGroups := Map()

; --- 初始化 ---
Main()

Main() {
    global collapsedWidth, collapsedX, expandedWidth, expandedX, ZoomFactor, guiY

    res := GetPhysicalScreenResolution()
    screenWidth := res[1]

    ; 展開時的寬度和座標
    expandedWidth := Round(screenWidth / 2 / ZoomFactor)
    expandedX := screenWidth // 4

    ; 摺疊時的寬度和座標
    collapsedWidth := Round(screenWidth / 4 / ZoomFactor)
    collapsedX := Round((screenWidth - (screenWidth / 4)) / 2)

    CreateGui()
    myGui.Show("NA x" collapsedX " y" guiY " w" collapsedWidth " h" collapsedHeight)

    SetRoundCorners(myGui.Hwnd, collapsedHeight)
    WinSetTransparent(0x80, myGui.Hwnd)

    SetTimer(CheckMouseHover, 50)
}

; --- GUI 控制 ---
CreateGui() {
    global myGui, exitBtn, contentListView, expandedWidth
    myGui := Gui("+AlwaysOnTop -Caption +ToolWindow", "RapidCopy")
    myGui.BackColor := "EEEEEF"
    myGui.SetFont("s" fontSize, "微軟正黑體 Bold")
    exitBtn := myGui.Add("Button", "w80 h30 Hidden", "離開")
    exitBtn.OnEvent("Click", (*) => ExitApp())
    contentListView := myGui.Add("ListView", "w" (expandedWidth - 40) " h" (expandedHeight - 80) " Hidden -Hdr", ["內容"])
    contentListView.OnEvent("Click", OnListViewClick)
}

Expand() {
    global isExpanded, myGui, exitBtn, contentListView, expandedWidth, expandedX, expandedHeight, guiY
    if (isExpanded)
        return
    isExpanded := true

    SetTimer(CheckMouseHover, 0) ; 停止偵測滑鼠移入

    exitBtn.Visible := true
    contentListView.Visible := true
    
    exitBtn.Move((expandedWidth // 2) - 40, expandedHeight - 40)
    contentListView.Move(20, 20)

    PopulateListView()

    myGui.Show("NA x" expandedX " y" guiY " w" expandedWidth " h" expandedHeight)
    WinSetTransparent(0xBF, myGui.Hwnd)
    SetRoundCorners(myGui.Hwnd, 10)

    ; **關鍵**：強制啟用 GUI 並在之後開始檢查焦點
    WinActivate(myGui.Hwnd)
    SetTimer(CheckFocusTimer, 100)
}

Collapse() {
    global isExpanded, myGui, exitBtn, contentListView, collapsedWidth, collapsedX, collapsedHeight, guiY
    if (!isExpanded)
        return
    isExpanded := false

    SetTimer(CheckFocusTimer, 0) ; 停止偵測焦點
    SetTimer(CheckMouseHover, 50) ; 重新開始偵測滑鼠移入

    exitBtn.Visible := false
    contentListView.Visible := false

    myGui.Show("NA x" collapsedX " y" guiY " w" collapsedWidth " h" collapsedHeight)
    WinSetTransparent(0x80, myGui.Hwnd)
    SetRoundCorners(myGui.Hwnd, collapsedHeight)
}

; --- 事件與計時器 ---
CheckMouseHover(*) {
    global collapsedX, collapsedWidth, guiY, collapsedHeight, ZoomFactor
    local mx, my
    MouseGetPos(&mx, &my)
    if (mx >= collapsedX && mx <= collapsedX + collapsedWidth * ZoomFactor && my >= guiY && my <= guiY + collapsedHeight * ZoomFactor)
        Expand()
}

CheckFocusTimer(*) {
    if !WinActive(myGui.Hwnd)
        Collapse()
}

OnListViewClick(lv, rowNumber) {
    global g_lineGroups
    if (rowNumber > 0) {
        A_Clipboard := g_lineGroups[rowNumber]
        ToolTip("已複製: " A_Clipboard)
        SetTimer(() => ToolTip(), -2000)
        SetTimer(Collapse, -400)
    }
}

PopulateListView() {
    global contentListView, g_lineGroups
    filePath := A_ScriptDir "\RapidCopy.txt"
    contentListView.Delete()
    g_lineGroups.Clear()
    if !FileExist(filePath) {
        contentListView.Add("", "找不到 'RapidCopy.txt'")
        return
    }
    fileContent := FileRead(filePath, "UTF-8")
    if (fileContent = "") {
        contentListView.Add("", "檔案是空的或讀取失敗")
        return
    }

    wasLastLineBlank := false
    Loop Parse, fileContent, "`n", "`r" {
        currentLine := A_LoopField
        if (SubStr(Trim(currentLine), 1, 1) = "#") {
            continue
        }

        if (currentLine = "") {
            if (!wasLastLineBlank) {
                rowNum := contentListView.Add("", "")
                g_lineGroups[rowNum] := ""
                wasLastLineBlank := true
            }
        } else {
            wasLastLineBlank := false
            textForClipboard := StrReplace(currentLine, "\n", "`n")
            
            displayParts := StrSplit(currentLine, "\n")
            for part in displayParts {
                rowNum := contentListView.Add("", part)
                g_lineGroups[rowNum] := textForClipboard
            }
        }
    }
    contentListView.ModifyCol(1, "AutoHdr")
}


; --- 輔助函式 ---
GetPhysicalScreenResolution() {
    hdc := DllCall("GetDC", "Ptr", 0, "Ptr")
    width := DllCall("GetDeviceCaps", "Ptr", hdc, "Int", 118)
    height := DllCall("GetDeviceCaps", "Ptr", hdc, "Int", 117)
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdc)
    return [width, height]
}

SetRoundCorners(hwnd, radius) {
    WinGetPos(,, &width, &height, hwnd)
    rgn := DllCall("CreateRoundRectRgn", "Int", 0, "Int", 0, "Int", width, "Int", height, "Int", radius, "Int", radius, "Ptr")
    DllCall("SetWindowRgn", "Ptr", hwnd, "Ptr", rgn, "Int", true)
}

GetZoomFactor() {
    global myGui
    ; 製作一個 100 x 100 的 GUI
    myGui := Gui("+AlwaysOnTop -Caption +ToolWindow", "RapidCopy")
    myGui.Show("Hide x 0 y 0 w 100 h 100")
    WinGetPos(,, &width,, myGui.Hwnd)
    myGui.Destroy()
    ; Msgbox "Zoom factor: " width/100
    return width/100
}
