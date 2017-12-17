(
var handler, midiOut;

midiOut = MIDIOut.newByName("IAC Driver", "Bus 2");
midiOut.latency = 0;

handler= {|msg, time, addr, recvPort|
	if(msg[4].asString == "on",
		{midiOut.noteOn(msg[1], msg[2], msg[3])},
		{midiOut.noteOff(msg[1], msg[2], msg[3])}
	);
};
OSCFunc(handler, "/spatializePlay");
)