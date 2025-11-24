package midi

Buttons :: struct {
	buttons: map[u8]u8,
	rows:    u8,
	columns: u8,
	modes:   map[string]Modes,
}

Modes :: struct {
	message: SysEx_Msg,
}

// Creates a new Buttons struct with the given number of rows and columns
// and initializes all buttons to 0
new_buttons :: proc(rows: u8, columns: u8) -> Buttons {
	empty_map: map[u8]u8 = {}
	for i in 0 ..< rows {
		for j in 0 ..< columns {
			empty_map[u8(i) * columns + u8(j)] = 0
		}
	}
	return Buttons{buttons = empty_map, rows = rows, columns = columns}
}

// Sets the value of a button at the given coordinates
// to the given value
set_button :: proc(b: ^Buttons, x: i32, y: i32, value: u8) {
	if x < 0 || y < 0 || x >= i32(b.columns) || y >= i32(b.rows) {
		return
	}
	b.buttons[u8(y) * b.columns + u8(x)] = value
}

// Gets the value of a button at the given coordinates
// Returns 0 if the coordinates are out of bounds or the button is not set
get_button :: proc(b: ^Buttons, x: i32, y: i32) -> u8 {
	if x < 0 || y < 0 || x >= i32(b.columns) || y >= i32(b.rows) {
		return 0
	}
	return b.buttons[u8(y) * b.columns + u8(x)]
}

// Sets the values of the buttons from a given map
set_buttons :: proc(b: ^Buttons, buttons: map[u8]u8) {
	for key, value in buttons {
		b.buttons[key] = value
	}
}

add_mode :: proc(b: ^Buttons, name: string, message: SysEx_Msg) {
	b.modes[name] = Modes {
		message = message,
	}
}

// Gets the SysEx message for the given mode
get_mode :: proc(b: ^Buttons, name: string) -> SysEx_Msg {
	return b.modes[name].message
}

remove_mode :: proc(b: ^Buttons, name: string) {
	delete_key(&b.modes, name)
}
