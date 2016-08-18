(var abletonOut;

MIDIClient.init;
abletonOut = MIDIOut.newByName("IAC Driver", "Bus 4");

(0..3).do({|i| (1..12).do({|j|
	OSCFunc.newMatching({|msg, time, addr, recvPort|
		var bank = msg[0].asString.split($/)[2].asInt;
		var fader = msg[0].asString.split($/)[3].asInt - 1;
		var ccNum = (bank*12) + fader;
		[bank, fader, ccNum, msg[1].asFloat.round, msg[0].asString.split($/)].postln;
		abletonOut.control(0, ccNum, msg[1].asFloat.round);
	}, "/faders/" ++ i.asString ++ "/" ++ j.asString);
})});
)

(
//FUNCTION TO "TWIDDLE KNOB" FOR A MIDI-CC
var twiddle = {|faderBankNum, faderNum, chan|
	var midiOut;
	var ccNum = (faderBankNum*12) + faderNum;

	MIDIClient.init;
	midiOut = MIDIOut.newByName("IAC Driver", "Bus 1");
	midiOut.latency = 0;

	Task({
		midiOut.control(chan, ccNum, 0);
		0.01.wait;
		midiOut.control(chan, ccNum, 127);
	}).play;
};
twiddle.value(0, 0);
)

