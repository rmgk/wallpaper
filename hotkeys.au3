

Global $pause = True

HotKeySet("+{END}" , "toggle")

;variables for axis
Const $AMIN = 5000
Const $AMAX = 65535 - $AMIN


global $joy = _JoyInit()

global $state, $last_state

;loading hotkeys from ini

global $button = IniReadSection ( "hotkeys.ini", "buttons" )
global $key = IniReadSection ( "hotkeys.ini", "key" )
global $axis = IniReadSection ( "hotkeys.ini", "axis" )
global $pov = IniReadSection ( "hotkeys.ini", "pov" )


for $i = 1 to UBound($button) - 1
	$button[$i][0] = Number($button[$i][0])
	$button[$i][1] = "wperl.exe change.pl " & $button[$i][1]
next 
for $i = 1 to UBound($pov) - 1
	$pov[$i][0] = Number($pov[$i][0])
	$pov[$i][1] = "wperl.exe change.pl " & $pov[$i][1]
next
for $i = 1 to UBound($axis) - 1
	$axis[$i][0] = Number($axis[$i][0])
	$axis[$i][1] = "wperl.exe change.pl " & $axis[$i][1]
next 
for $i = 1 to UBound($key) - 1
	$key[$i][1] = "wperl.exe change.pl " & $key[$i][1]
next 

;main loop

while 1
	$last_state = $state
    $state = _GetJoy($joy,0)
	
	if $state then		
		for $i = 1 to UBound($button) - 1
			if button($button[$i][0]) then run($button[$i][1])
		next 
		for $i = 1 to UBound($pov) - 1
			if pov($pov[$i][0]) then run($pov[$i][1])
		next 
		for $i = 1 to UBound($axis) - 1
			if axis($axis[$i][0]) then run($axis[$i][1])
		next 
		sleep(10)
	else
		sleep(100)
	endif

WEnd

Func hotkeyPressed()
	for $i = 1 to UBound($key) - 1
		if @HotKeyPressed = $key[$i][0] then run($key[$i][1] )
	next 
EndFunc

func setHotkeys()
	for $i = 1 to UBound($key) - 1
		HotKeySet($key[$i][0], "hotkeyPressed")
	next 
EndFunc

Func unsetHotkeys()
	for $i = 1 to UBound($key) - 1
		HotKeySet($key[$i][0])
	next 
EndFunc

Func axis($id)
	$sid = abs($id) - 1
	if $id < 0 then
		if $state[$sid] <= $AMIN and $last_state[$sid] > $AMIN then return true
		return false
	endif
	if $id > 0 then
		if $state[$sid] >= $AMAX and $last_state[$sid] < $AMAX then return true
		return false
	endif 
EndFunc

Func button($id)
	if BitAND($state[7],$id) = $id and BitAND($last_state[7],$id) <> $id then return true
	return false
EndFunc

Func pov($dir)
	local $d = $dir * 4500
	if $state[6] = $d and $last_state[6] <> $d then return true
	return false
EndFunc

Func toggle()
		$pause = NOT $pause
		if $pause then 
			unsetHotkeys()
		else 
			setHotkeys()
		endif
EndFunc

;======================================
;   _JoyInit()
;======================================
Func _JoyInit()
    Local $joy
    Global $JOYINFOEX_struct    = "dword[13]"

    $joy=DllStructCreate($JOYINFOEX_struct)
    if @error Then Return 0
    DllStructSetData($joy, 1, DllStructGetSize($joy), 1);dwSize = sizeof(struct)
    DllStructSetData($joy, 1, 255, 2)              ;dwFlags = GetAll
    return $joy
EndFunc

;======================================
;   _GetJoy($lpJoy,$iJoy)
;   $lpJoy  Return from _JoyInit()
;   $iJoy   Joystick # 0-15
;   Return  Array containing X-Pos, Y-Pos, Z-Pos, R-Pos, U-Pos, V-Pos,POV
;           Buttons down
;
;           *POV This is a digital game pad, not analog joystick
;           65535   = Not pressed
;           0       = U
;           4500    = UR
;           9000    = R
;           Goes around clockwise increasing 4500 for each position
;======================================
Func _GetJoy($lpJoy,$iJoy)
    Local $coor,$ret

    Dim $coor[8]
    DllCall("Winmm.dll","int","joyGetPosEx", _
            "int",$iJoy, _
            "ptr",DllStructGetPtr($lpJoy))

    if Not @error Then
        $coor[0]    = DllStructGetData($lpJoy,1,3)
        $coor[1]    = DllStructGetData($lpJoy,1,4)
        $coor[2]    = DllStructGetData($lpJoy,1,5)
        $coor[3]    = DllStructGetData($lpJoy,1,6)
        $coor[4]    = DllStructGetData($lpJoy,1,7)
        $coor[5]    = DllStructGetData($lpJoy,1,8)
        $coor[6]    = DllStructGetData($lpJoy,1,11)
        $coor[7]    = DllStructGetData($lpJoy,1,9)
    EndIf

    return $coor
EndFunc