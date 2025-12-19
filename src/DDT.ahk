#Requires AutoHotkey v2.0
SendMode 'Input'
SetWorkingDir A_ScriptDir

#Include Gdip_All.ahk  ; buliasz/AHKv2-Gdip library

; === CSV PARSER ===
LoadBossData() {
    if !FileExist('boss_health.csv') {
        MsgBox('boss_health.csv is missing!', 'Error')
        ExitApp
    }

    bosses := Map(), categories := []
    csv := FileRead('boss_health.csv')

    Loop Parse, csv, '`n', '`r' {
        if (A_LoopField = '' || InStr(A_LoopField, 'category,values'))
            continue

        parts := StrSplit(A_LoopField, ',', 2)
        if (parts.Length < 2)
            continue
        category := Trim(parts[1], '" ')
        json_str := Trim(parts[2], '" ')

        boss_list := ParseJSONBosses(json_str)
        categories.Push({ name: category, bosses: boss_list })

        for boss in boss_list
            bosses[boss.name] := boss
    }

    return { categories: categories, bosses: bosses }
}

ParseJSONBosses(json_str) {
    bosses := []
    json_str := RegExReplace(json_str, '\s', '')

    if (!RegExMatch(json_str, '\[(.*?)\]', &match))
        return bosses

    array_content := match[1]

    Loop Parse, array_content, '},{', '`n' {
        obj_str := RegExReplace(A_LoopField, '^[{}]|[\s{}]', '')
        if (obj_str = '')
            continue

        boss := { name: '', health: 0, final_stand: false }

        if RegExMatch(obj_str, '"name":"([^"]+)"', &m)
            boss.name := m[1]
        if RegExMatch(obj_str, '"health":(\d+)', &m)
            boss.health := m[1] + 0
        if RegExMatch(obj_str, '"final_stand":(true|false)', &m)
            boss.final_stand := (m[1] = 'true')

        bosses.Push(boss)
    }
    return bosses
}

MsgBox(LoadBossData())

; === MAIN SCRIPT ===
pToken := Gdip_Startup()
data := LoadBossData()

; Config - ADJUST THESE COORDINATES FOR YOUR SCREEN
healthbar_area := '858|1302|845|3'  ; x|y|width|height
health_colors := Map()
current_boss := { name: 'Carl', health: 1500000, final_stand: false }

; State
dps_phase_active := false, total_damage := 0, highest_dps := 0
last_hp_percent := 100, time_of_last_damage := 0, dps_start_time := 0
currently_shown := true

; === OVERLAY GUI ===
overlay := Gui('-Caption +AlwaysOnTop +ToolWindow +E0x20 +LastFound')
overlay.BackColor := '0x010101'
WinSetTransColor('0x010101')
overlay.MarginX := overlay.MarginY := 5
overlay.SetFont('s20 cLime Bold', 'Consolas')

; UI Controls
hp_percent := overlay.Add('Text', 'w280 h40 +Center vHPPercent cWhite', '100.00%')
hp_total := overlay.Add('Text', 'w280 h30 +Center vHPTotal', '1.5M / 1.5M')
dps_row1 := overlay.Add('Text', 'w135 h35 +Center vDPSAvg cWhite', 'Avg: 0')
dps_row2 := overlay.Add('Text', 'x145 w135 h35 +Center vDPSHigh cWhite', 'High: 0')
duration := overlay.Add('Text', 'w280 h30 +Center vDuration', 'Waiting...')
boss_name := overlay.Add('Text', 'w280 h25 +Center cWhite vBossName', current_boss.name)

overlay.Show('x900 y50 w290 h195 NoActivate')

; === SETTINGS GUI ===
settings := Gui('+Resize', 'Boss Selector')
settings.SetFont('s12', 'Arial')

category_list := settings.Add('DropDownList', 'x10 y10 w200 vCategory')
for category in data.categories
    category_list.Add(category.name)

boss_list := settings.Add('DropDownList', 'x10 y40 w200 vBossName', 'Carl')
UpdateBossList()

status_label := settings.Add('Text', 'x10 y75 w300', 'F3: Toggle DPS | F2: Settings')
start_btn := settings.Add('Button', 'x220 y70 w90 h30 +Default', 'Start Monitor')

category_list.OnEvent('Change', UpdateBossList)
start_btn.OnEvent('Click', StartMonitoring)
settings.Show('w320 h120')

UpdateBossList(*) {
    sel_cat := category_list.Text
    boss_list.Delete()
    for cat in data.categories {
        if (cat.name = sel_cat) {
            for boss in cat.bosses
                boss_list.Add(boss.name)
            break
        }
    }
}

StartMonitoring(*) {
    global current_boss
    current_boss.name := boss_list.Text
    for boss in data.bosses {
        if (boss.name = current_boss.name) {
            current_boss := boss
            break
        }
    }
    boss_name.Text := current_boss.name
    settings.Hide()
    GenerateHealthColors()
    SetTimer(MonitorLoop, 40)
}

GenerateHealthColors() {
    global health_colors
    ; Destiny 2 orange health bar colors
    dark := 0xD39621, light := 0xEDB147
    darkRGB := [211, 150, 33], lightRGB := [237, 177, 71]

    health_colors.Clear()
    for r in Range(darkRGB[1], lightRGB[1])
        for g in Range(darkRGB[2], lightRGB[2])
            for b in Range(darkRGB[3], lightRGB[3])
                health_colors[Format('0x{:02X}{:02X}{:02X}', r, g, b)] := true
}

MonitorLoop() {
    static loop_count := 0
    loop_count++

    ; Only show when Destiny 2 is active
    if !WinActive('ahk_exe Destiny2.exe') {
        if currently_shown {
            overlay.Hide()
            currently_shown := false
        }
        return
    }

    if !currently_shown {
        overlay.Show('NoActivate')
        currently_shown := true
    }


    pBitmap := Gdip_BitmapFromScreen(healthbar_area)
    hp_percent := GetHealthPercent(pBitmap)
    Gdip_DisposeImage(pBitmap)

    UpdateDPS(hp_percent)
    last_hp_percent := hp_percent

    UpdateDisplay()
}

GetHealthPercent(pBitmap) {
    global health_colors
    Gdip_GetImageDimensions(pBitmap, &w, &h)

    total_pixels := w * h
    health_pixels := 0

    Loop w {
        Loop h {
            color := Gdip_GetPixel(pBitmap, A_Index - 1, A_Index - 1)
            if health_colors.Has(color)
                health_pixels++
        }
    }

    return Round((health_pixels / total_pixels) * 100, 2)
}

UpdateDPS(current_hp) {
    global

    ; Auto-start DPS phase on damage
    if (!dps_phase_active && current_hp < last_hp_percent) {
        dps_phase_active := true
        dps_start_time := A_TickCount
        time_of_last_damage := A_TickCount
        total_damage := highest_dps := 0
    }

    if (dps_phase_active) {
        damage_this_tick := (last_hp_percent - current_hp) * current_boss.health / 100
        if (damage_this_tick > 0) {
            total_damage += damage_this_tick
            time_of_last_damage := A_TickCount
        }

        elapsed := (A_TickCount - dps_start_time) / 1000
        if (elapsed >= 0.25) {
            current_dps := total_damage / elapsed
            highest_dps := Max(highest_dps, current_dps)
        }

        ; End phase after 8s no damage
        if (A_TickCount - time_of_last_damage >= 8000) {
            dps_phase_active := false
            total_damage := highest_dps := 0
        }
    }
}

UpdateDisplay() {
    global hp_percent, hp_total, dps_row1, dps_row2, duration, boss_name, current_boss
    global dps_phase_active, total_damage, highest_dps, dps_start_time, last_hp_percent

    hp_percent.Text := last_hp_percent '%'
    hp_total.Text := FormatNumber(Round((last_hp_percent / 100) * current_boss.health)) ' / ' FormatNumber(current_boss.health)

    if (dps_phase_active) {
        elapsed := Round((A_TickCount - dps_start_time) / 1000, 1)
        current_dps := Round(total_damage / elapsed)
        dps_row1.Text := 'Avg: ' FormatNumber(current_dps)
        dps_row2.Text := 'High: ' FormatNumber(highest_dps)
        duration.Text := elapsed 's'
    } else {
        dps_row1.Text := 'Avg: 0'
        dps_row2.Text := 'High: 0'
        duration.Text := 'Waiting for damage...'
    }
}

FormatNumber(num) => RegExReplace(num, '(\d)(?=(?:\d{3})+(?:\.|$))', '$1,')
Range(start, end) {
    result := []
    Loop (end - start + 1)
        result.Push(start + A_Index - 1)
    return result
}

; === HOTKEYS ===
F2:: settings.Show()
F3::
{
    global dps_phase_active, dps_start_time, total_damage, highest_dps, time_of_last_damage
    dps_phase_active := !dps_phase_active
    if (dps_phase_active) {
        dps_start_time := A_TickCount
        time_of_last_damage := A_TickCount
        total_damage := highest_dps := 0
    }
}
F4:: ExitApp
F5:: Reload

OnExit((*) => (Gdip_Shutdown(pToken), overlay.Destroy()))