package midi

import "core:fmt"
import "core:strings"
import "core:time"
import "vendor:portmidi"

// Launchpad Mini MK3 Programmer's Reference Manual
// https://fael-downloads-prod.focusrite.com/customer/prod/s3fs-public/downloads/Launchpad%20Mini%20-%20Programmers%20Reference%20Manual.pdf

// Launchpad Mini MK3 MIDI Implementation
note_matrix: [8][8]u8 = {
	{64, 65, 66, 67, 96, 97, 98, 99},
	{60, 61, 62, 63, 92, 93, 94, 95},
	{56, 57, 58, 59, 88, 89, 90, 91},
	{52, 53, 54, 55, 84, 85, 86, 87},
	{48, 49, 50, 51, 80, 81, 82, 83},
	{44, 45, 46, 47, 76, 77, 78, 79},
	{40, 41, 42, 43, 72, 73, 74, 75},
	{36, 37, 38, 39, 68, 69, 70, 71},
}

// Programmer's matrix
programmer_matrix: [9][9]u8 = {
	{91, 92, 93, 94, 95, 96, 97, 98, 99},
	{81, 82, 83, 84, 85, 86, 87, 88, 89},
	{71, 72, 73, 74, 75, 76, 77, 78, 79},
	{61, 62, 63, 64, 65, 66, 67, 68, 69},
	{51, 52, 53, 54, 55, 56, 57, 58, 59},
	{41, 42, 43, 44, 45, 46, 47, 48, 49},
	{31, 32, 33, 34, 35, 36, 37, 38, 39},
	{21, 22, 23, 24, 25, 26, 27, 28, 29},
	{11, 12, 13, 14, 15, 16, 17, 18, 19},
}

// SysEx messages

SysEx_Msg :: struct {
	header: []u8,
	data:   []u8,
	footer: []u8,
}

Device :: struct {
	name:          string,
	useInput:      bool,
	useOutput:     bool,
	input:         portmidi.DeviceID,
	output:        portmidi.DeviceID,
	input_stream:  portmidi.Stream,
	output_stream: portmidi.Stream,
}

isMidiPadInitialized: bool = false

Error :: enum {
	None,
	FailedToWriteNote,
	FailedToDrawPixel,
	FailedToInitializePortMidi,
	FailedToOpenOutput,
	FailedToOpenInput,
	FailedToGetMidiDevices,
}

printMidiDevices :: proc() {
	ds := getMidiDevices()
	if ds == nil {
		fmt.printfln("Failed to get MIDI devices")
		return
	}
	for device, _ in ds {
		fmt.printfln("Device Name: %v", string(device.name))
	}
}

newMidiDevice :: proc(name: string, useInput: bool, useOutput: bool) -> Device {
	return Device{name = name, useInput = useInput, useOutput = useOutput}
}

initMidiPad :: proc(devices: []Device) {
	if isMidiPadInitialized {return}

	if err := portmidi.Initialize(); err != nil {
		fmt.printfln("Failed to initialize portmidi: %v", err)
		return
	}

	if devices == nil {
		fmt.printfln("No devices provided")
		return
	}
	ds := getMidiDevices()
	if ds == nil {
		fmt.printfln("Failed to get MIDI devices")
		return
	}
	for device, i in ds {
		for _, j in devices {

			if devices[j].useInput &&
			   device.input &&
			   strings.equal_fold(string(device.name), devices[j].name) {

				devices[j].input = (portmidi.DeviceID)(i)

				if err := portmidi.OpenInput(
					&devices[j].input_stream,
					devices[j].input,
					nil,
					1024,
					nil,
					nil,
				); err != nil {
					fmt.printfln("Failed to open output: %v", err)
					fmt.printfln("Device Input ID: %v", i)
					fmt.printfln("Device Index: %v", j)
					fmt.printfln("Device Name: %v", string(device.name))
					fmt.printfln("Name: %v", devices[j].name)
					return
				}

				fmt.printfln("Device Input ID: %v", i)
				fmt.printfln("Device Index: %v", j)
				fmt.printfln("Device Name: %v", string(device.name))
				fmt.printfln("Name: %v", devices[j].name)

			} else if devices[j].useOutput &&
			   device.output &&
			   strings.equal_fold(string(device.name), devices[j].name) {

				devices[j].output = (portmidi.DeviceID)(i)

				if err := portmidi.OpenOutput(
					&devices[j].output_stream,
					devices[j].output,
					nil,
					1024,
					nil,
					nil,
					0,
				); err != nil {
					fmt.printfln("Failed to open output: %v", err)
					fmt.printfln("Device ID: %v", i)
					fmt.printfln("Device Index: %v", j)
					fmt.printfln("Device Name: %v", string(device.name))
					fmt.printfln("Name: %v", devices[j].name)
					return
				}
			}
		}
	}

	isMidiPadInitialized = true
}

closeMidiPad :: proc(devices: []Device) {
	if !isMidiPadInitialized {return}
	for _, i in devices {
		if devices[i].useInput {
			portmidi.Close(devices[i].input_stream)
		}
		if devices[i].useOutput {
			portmidi.Close(devices[i].output_stream)
		}
	}
	portmidi.Terminate()
}

getMidiDevices :: proc() -> (devices: [dynamic]^portmidi.DeviceInfo) {
	// Get devices
	for i: i32 = 0; i < portmidi.CountDevices() - 1; i = i + 1 {
		append(&devices, portmidi.GetDeviceInfo((portmidi.DeviceID)(i)))
	}
	return
}

play_note :: proc(stream: portmidi.Stream, note: i32, velocity: i32, duration: int) {
	if err := portmidi.WriteShort(stream, 0, portmidi.MessageCompose(0x90, note, velocity));
	   err != nil {
		fmt.printfln("Failed to write note: %v", err)
	}
	time.sleep(time.Duration(duration) * time.Millisecond)
	if err := portmidi.WriteShort(stream, 0, portmidi.MessageCompose(0x80, note, velocity));
	   err != nil {
		fmt.printfln("Failed to write note: %v", err)
	}
}

draw_pixel :: proc(stream: portmidi.Stream, x: int, y: int, color: i32) -> Error {
	if err := portmidi.WriteShort(
		stream,
		0,
		portmidi.MessageCompose(0x90, i32(note_matrix[y][x]), color),
	); err != nil {
		fmt.printfln("Failed to draw pixel: %v", err)
		return .FailedToDrawPixel
	}
	return .None
}

clear_matrix :: proc(stream: portmidi.Stream) -> Error {
	for i, y in note_matrix {
		for _, x in i {
			draw_pixel(stream, x, y, 0) or_return
		}
	}
	return .None
}

draw_line :: proc(
	stream: portmidi.Stream,
	x1: int,
	y1: int,
	x2: int,
	y2: int,
	color: i32,
) -> Error {
	x1, x2 := x1, x2
	y1, y2 := y1, y2
	dx := x2 - x1
	dy := y2 - y1
	if dx == 0 {
		for y := y1; y <= y2; y = y + 1 {
			draw_pixel(stream, x1, y, color) or_return
		}
	} else if dy == 0 {
		for x := x1; x <= x2; x = x + 1 {
			draw_pixel(stream, x, y1, color) or_return
		}
	} else {
		if abs(dy) > abs(dx) {
			if dy < 0 {
				x1, x2 = x2, x1
				y1, y2 = y2, y1
			}
			dx = x2 - x1
			dy = y2 - y1
			for y := y1; y <= y2; y = y + 1 {
				x := x1 + dx * (y - y1) / dy
				draw_pixel(stream, x, y, color) or_return
			}
		} else {
			if dx < 0 {
				x1, x2 = x2, x1
				y1, y2 = y2, y1
			}
			dx = x2 - x1
			dy = y2 - y1
			for x := x1; x <= x2; x = x + 1 {
				y := y1 + dy * (x - x1) / dx
				draw_pixel(stream, x, y, color) or_return
			}
		}
	}
	return .None
}

draw_rectangle :: proc(
	stream: portmidi.Stream,
	x: int,
	y: int,
	width: int,
	height: int,
	color: i32,
) -> Error {
	draw_line(stream, x, y, x, height, color) or_return
	draw_line(stream, x, y, width, y, color) or_return
	draw_line(stream, width, y, width, height, color) or_return
	draw_line(stream, x, height, width, height, color) or_return
	return .None
}

draw_pixel_lighting :: proc(stream: portmidi.Stream, colours: []colourspec) {
	header: []u8 = {0xF0, 0x00, 0x20, 0x29, 0x02, 0x0D, 0x03}
	// <colourspec> [<colourspec> […]]
	footer: []u8 = {0xF7}

	c := new_colourspec(colours)
	msg: []u8 = make([]u8, len(header) + len(c) + len(footer))
	i := 0
	for j, _ in header {
		msg[i] = j
		i = i + 1
	}
	for j, _ in c {
		msg[i] = j
		i = i + 1
	}
	for j, _ in footer {
		msg[i] = j
		i = i + 1
	}
	m, _ := strings.clone_from_bytes(msg)
	portmidi.WriteSysEx(stream, 0, strings.clone_to_cstring(m))

}

colourspec :: struct {
	type:  lighting_type,
	index: u8,
	data:  []u8,
}

lighting_type :: enum {
	static   = 0,
	flashing = 1,
	pulsing  = 2,
	rgb      = 3,
}

new_colourspec :: proc(colours: []colourspec) -> []u8 {
	length := 0
	for colour in colours {
		switch colour.type {
		case .static:
			{
				assert(len(colour.data) == 1)
				length = length + 3
			}
		case .flashing:
			{
				assert(len(colour.data) == 2)
				length = length + 4
			}
		case .pulsing:
			{
				assert(len(colour.data) == 1)
				length = length + 3
			}
		case .rgb:
			{
				assert(len(colour.data) == 3)
				length = length + 5
			}
		}
	}


	d: []u8 = make([]u8, length)
	i := 0
	for colour in colours {
		if colour.type == lighting_type.static {
			d[i] = 0
			d[i + 1] = colour.index
			d[i + 2] = colour.data[0]
			i = i + 3
		}
		if colour.type == lighting_type.flashing {
			d[i] = 1
			d[i + 1] = colour.index
			d[i + 2] = colour.data[0]
			d[i + 3] = colour.data[1]
			i = i + 4
		}
		if colour.type == lighting_type.pulsing {
			d[i] = 2
			d[i + 1] = colour.index
			d[i + 2] = colour.data[0]
			i = i + 3
		}
		if colour.type == lighting_type.rgb {
			d[i] = 3
			d[i + 1] = colour.index
			d[i + 2] = colour.data[0]
			d[i + 3] = colour.data[1]
			d[i + 4] = colour.data[2]
			i = i + 5
		}
	}

	return d
}
