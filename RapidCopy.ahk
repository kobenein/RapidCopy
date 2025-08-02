; TODO
; BUG: 觸發區域與GUI寬度不同步
; 功能: 選擇性 在上或左
; 功能: 摺疊時寬度為螢幕解析度的1/4，展開時寬度為螢幕解析度的1/2
; 功能: 支援文件換行符號


#Requires AutoHotkey v2.0
#SingleInstance Force

; --- 全域設定 ---
CoordMode "Mouse", "Screen"

; --- 全域變數 ---
global isExpanded := false
global fontSize := 14
global collapsedHeight := 6, expandedHeight := 800
global guiWidth := 0, guiX := 0, guiY := 0
global myGui, exitBtn, contentListView

; --- 初始化 ---
Main()

Main() {
    global guiWidth, guiX
    if !DllCall("SetProcessDpiAwarenessContext", "Int", -4)
        DllCall("SetProcessDPIAware")

    res := GetPhysicalScreenResolution()
    screenWidth := res[1]
    guiWidth := screenWidth // 2
    guiX := screenWidth // 4

    CreateGui()
    
    ; 先用 Hide 畫 GUI (但不顯示)，然後計算實際寬度
    myGui.Show("Hide x" guiX " y" guiY " w" guiWidth " h" collapsedHeight)
    WinGetPos(,,&actualWidth,, myGui.Hwnd)

    ; 重計算 GUI 的位置，讓它水平置中
    guiX := (screenWidth - actualWidth) // 2
    myGui.Show("NA x" guiX " y" guiY " w" guiWidth " h" collapsedHeight)

    SetRoundCorners(myGui.Hwnd, collapsedHeight)
    WinSetTransparent(128, myGui.Hwnd)

    SetTimer(CheckMouseHover, 50)
}

; --- GUI 控制 ---
CreateGui() {
    global myGui, exitBtn, contentListView
    myGui := Gui("+AlwaysOnTop -Caption +ToolWindow", "RapidCopy")
    myGui.BackColor := "EEEEEF"
    myGui.SetFont("s" fontSize, "微軟正黑體 Bold")
    exitBtn := myGui.Add("Button", "w80 h30 Hidden", "離開")
    exitBtn.OnEvent("Click", (*) => ExitApp())
    contentListView := myGui.Add("ListView", "w" (guiWidth - 40) " h" (expandedHeight - 80) " Hidden -Hdr", ["內容"])
    contentListView.OnEvent("Click", OnListViewClick)
}

Expand() {
    global isExpanded, myGui, exitBtn, contentListView
    if (isExpanded)
        return
    isExpanded := true

    SetTimer(CheckMouseHover, 0) ; 停止偵測滑鼠移入

    exitBtn.Visible := true
    contentListView.Visible := true
    
    exitBtn.Move((guiWidth // 2) - 40, expandedHeight - 40)
    contentListView.Move(20, 20)

    PopulateListView()

    myGui.Show("NA x" guiX " y" guiY " w" guiWidth " h" expandedHeight)
    WinSetTransparent(255, myGui.Hwnd)
    SetRoundCorners(myGui.Hwnd, 10)

    ; **關鍵**：強制啟用 GUI 並在之後開始檢查焦點
    WinActivate(myGui.Hwnd)
    SetTimer(CheckFocusTimer, 100)
}

Collapse() {
    global isExpanded, myGui, exitBtn, contentListView
    if (!isExpanded)
        return
    isExpanded := false

    SetTimer(CheckFocusTimer, 0) ; 停止偵測焦點
    SetTimer(CheckMouseHover, 50) ; 重新開始偵測滑鼠移入

    exitBtn.Visible := false
    contentListView.Visible := false

    myGui.Show("NA x" guiX " y" guiY " w" guiWidth " h" collapsedHeight)
    WinSetTransparent(128, myGui.Hwnd)
    SetRoundCorners(myGui.Hwnd, 2)
}

; --- 事件與計時器 ---
CheckMouseHover(*) {
    local mx, my
    MouseGetPos(&mx, &my)
    if (mx >= guiX && mx <= guiX + guiWidth && my >= guiY && my <= guiY + collapsedHeight)
        Expand()
}

CheckFocusTimer(*) {
    if !WinActive(myGui.Hwnd)
        Collapse()
}

OnListViewClick(lv, rowNumber) {
    if (rowNumber > 0) {
        A_Clipboard := lv.GetText(rowNumber)
        ToolTip("已複製: " A_Clipboard)
        SetTimer(() => ToolTip(), -2000)
        SetTimer(Collapse, -400)
    }
}

UpdateGuiFont() {
    global myGui, contentListView

    ; Store current content
    items := []
    Loop contentListView.GetCount()
        items.Push(contentListView.GetText(A_Index))

    ; Store position and delete
    contentListView.GetPos(&lvX, &lvY, &lvW, &lvH)
    contentListView.Delete()

    ; Recreate the ListView
    contentListView := myGui.Add("ListView", "x" lvX " y" lvY " w" lvW " h" lvH " -Hdr", ["內容"])
    contentListView.OnEvent("Click", OnListViewClick)

    ; Repopulate
    for item in items
        contentListView.Add("", item)
    
    contentListView.ModifyCol(1, "AutoHdr")
}

PopulateListView() {
    global contentListView
    filePath := A_ScriptDir "\RapidCopy.txt"
    contentListView.Delete()
    if !FileExist(filePath) {
        contentListView.Add("", "找不到 'RapidCopy.txt'")
        return
    }
    fileContent := FileRead(filePath, "UTF-8")
    if (fileContent = "") {
        contentListView.Add("", "檔案是空的或讀取失敗")
        return
    }
    Loop Parse, fileContent, "`n", "`r" {
        if (A_LoopField != "")
            contentListView.Add("", A_LoopField)
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