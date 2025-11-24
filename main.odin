package main

import "core:fmt"
import "core:os"
import "core:time"

import "midi"

// Colour Escape codes
red_escapecode := "\e[31m"
green_escapecode := "\e[32m"
yellow_escapecode := "\e[33m"
reset_escapecode := "\e[0m"


Tag_Error := "[\e[31mError\e[0m]"
Tag_Warning := "[\e[33mWarning\e[0m]"
Tag_Info := "[\e[32mInfo\e[0m]"

App_Version := "0.0.1"

main :: proc() {

	// Parse command line arguments
	args := os.args
	for i := 0; i < len(args); i = i + 1 {

		arg := args[i]

		switch arg {

		case "-h", "--help":
			fmt.printfln("Usage: %s [options]", args[0])
			fmt.printfln("Options:")
			fmt.printfln("  -h, --help  Display this help message")
			fmt.printfln("  -d, --devices, --list-devices  List MIDI devices")
			fmt.printfln("  -v, --version  Display version information")
			return

		case "-d", "--devices", "--list-devices":
			fmt.printfln("MIDI devices:")
			midi.printMidiDevices()
			return

		case "-v", "--version":
			fmt.printfln("Version: %s", App_Version)
			return

		case:
			if i == 0 {
				// Skip the executable name
				continue
			}
			fmt.printfln("%s Unknown option: %s", Tag_Warning, arg)
			return
		}
	}

	// Initialize MIDI pad
	devices: [2]midi.Device = {
		midi.newMidiDevice(
			name = "Launchpad Mini MK3 LPMiniMK3 MI",
			useInput = false,
			useOutput = true,
		),
		midi.newMidiDevice(
			name = "Launchpad Mini MK3 LPMiniMK3 DA",
			useInput = false,
			useOutput = false,
		),
	}

	midi.initMidiPad(devices[:])
	defer midi.closeMidiPad(devices[:])
	if !midi.isMidiPadInitialized {
		// Print MIDI devices
		fmt.printfln("MIDI devices:")
		midi.printMidiDevices()
		fmt.printfln("%s Failed to initialize MIDI pad", Tag_Error)
		return
	}

	fmt.printfln("")

	// Fill the matrix
	{
		if err := midi.clear_matrix(devices[0].output_stream); err != midi.Error.None {
			fmt.printfln("%s Failed to clear matrix", Tag_Error)
			return
		}
		fmt.printfln("%v", yellow_escapecode)
		for i, y in midi.note_matrix {
			for _, x in i {
				time.sleep(time.Duration(20) * time.Millisecond)
				midi.draw_pixel(devices[0].output_stream, x, y, 127)
				fmt.printf("X")
			}
			fmt.printfln("")
		}
		fmt.printf("%v", reset_escapecode)
	}

	// Draw a square
	{
		midi.clear_matrix(devices[0].output_stream)
		time.sleep(time.Duration(20) * time.Millisecond)

		if err := midi.draw_rectangle(devices[0].output_stream, 0, 0, 7, 7, 120);
		   err != midi.Error.None {
			fmt.printfln("%s Failed to draw rectangle", Tag_Error)
			return
		}

		fmt.printf("\e[8A;\e[8D") // Move cursor up 8 lines and left 8 columns
		fmt.printfln("%vXXXXXXXX", red_escapecode)
		fmt.printfln("X      X")
		fmt.printfln("X      X")
		fmt.printfln("X      X")
		fmt.printfln("X      X")
		fmt.printfln("X      X")
		fmt.printfln("X      X")
		fmt.printfln("%vXXXXXXXX%v", red_escapecode, reset_escapecode)
		time.sleep(time.Duration(500) * time.Millisecond)
	}

	// Draw a checkmark
	{
		time.sleep(time.Duration(20) * time.Millisecond)

		midi.draw_line(devices[0].output_stream, 2, 4, 3, 5, 123)
		midi.draw_line(devices[0].output_stream, 3, 5, 6, 2, 123)

		fmt.printf("\e[8A;\e[8D") // Move cursor up 8 lines and left 8 columns
		fmt.printfln("%vXXXXXXXX", red_escapecode)
		fmt.printfln("%vX      X", red_escapecode)
		fmt.printfln("%vX     %vX%vX", red_escapecode, green_escapecode, red_escapecode)
		fmt.printfln("%vX    %vX %vX", red_escapecode, green_escapecode, red_escapecode)
		fmt.printfln("%vX %vX X  %vX", red_escapecode, green_escapecode, red_escapecode)
		fmt.printfln("%vX  %vX   %vX", red_escapecode, green_escapecode, red_escapecode)
		fmt.printfln("%vX      X", red_escapecode)
		fmt.printfln("%vXXXXXXXX%v", red_escapecode, reset_escapecode)
		time.sleep(time.Duration(1) * time.Second)
	}

	midi.clear_matrix(devices[0].output_stream)
	fmt.printfln("")

	{
		fill: [9 * 9]midi.colourspec
		i := 0
		for x in 0 ..< 9 {
			for y in 0 ..< 9 {
				fill[i] = midi.colourspec {
					type  = midi.lighting_type.static,
					index = midi.programmer_matrix[y][x],
					data  = []u8{127},
				}
				i = i + 1
			}
		}
		midi.draw_pixel_lighting(devices[0].output_stream, fill[:])
		time.sleep(time.Duration(1) * time.Second)
	}
	midi.clear_matrix(devices[0].output_stream)
	fmt.printfln("")

}
