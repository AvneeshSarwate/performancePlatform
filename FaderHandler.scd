(var abletonOut, sliderVals, paramsToString, stringToParams, savedBanks;


MIDIClient.init;
abletonOut = MIDIOut.newByName("IAC Driver", "Bus 4");
ipadPort = NetAddr("192.168.1.104", 9000);

sliderVals = List.fill(4, {List.fill(12, {0})});
savedBanks = List.fill(4, { List.fill(4, {List.fill(12, {0})}) });

(0..3).do({|i| (1..12).do({|j|

	//slider hanlders msg[1] is val
	OSCFunc.newMatching({|msg, time, addr, recvPort|
		var bank = msg[0].asString.split($/)[2].asInt;
		var fader = msg[0].asString.split($/)[3].asInt - 1;
		var val = msg[1].asFloat.round;
		var ccNum = (bank*12) + fader;
		sliderVals[bank][fader] = val;
		[bank, fader, ccNum, val, msg[0].asString.split($/)].postln;
		abletonOut.control(0, ccNum, val);
	}, "/faders/" ++ i.asString ++ "/" ++ j.asString);

	OSCFunc.newMatching({|msg, time, addr, recvPort|
		var bank = msg[0].asString.split($/)[2].asInt;
		var slot = msg[0].asString.split($/)[4].asInt - 1;
		var val = msg[1].asFloat.round;
		if(val == 0,
			{}, //TODO: do anything for "erasing" a parameter bank slot?
			{savedBanks[bank][slot] = List.copyInstance(sliderVals[bank])},
		);

		//TODO: send to python

	}, "/saveBank/" ++ i.asString ++ "/1/" ++ j.asString);
	//extra /1/ because verticla control where addresses are /widgetBaseAddr/x/y

	OSCFunc.newMatching({|msg, time, addr, recvPort|
		var bank = msg[0].asString.split($/)[2].asInt;
		var slot = msg[0].asString.split($/)[4].asInt - 1;
		var val = msg[1].asFloat.round;
		if(val != 0, {
			sliderVals[bank] = List.copyInstance(savedBanks[bank][slot]);
			(0..11).do({|i|
				abletonOut.control(0, (bank*12)+i, sliderVals[bank][i]);
				ipadPort.sendMsg("/faders/" ++ bank.asString + "/" ++ (i+1).asString, sliderVals[bank][i]);
			});
		});
	}, "/playBank/" ++ i.asString ++ "/1/" ++ j.asString);
})});

//msg[1] is string encoding of params
OSCFunc({|msg, time, addr, recvPort|
	var params = stringToParams.(msg[1].asString);
	(0..3).do({|i| (0..11).do({|j|
		ipadPort.sendMsg("/faders/" ++ i.asString ++ "/" ++ (j+1).asString, params[i][j]);
		abletonOut.control(0, (i*4)+j, params[i][j]);
	})});
}, "/loadParams");

paramsToString = {|params| "-".join(sliderVals.collect({|bankVals| ",".join(bankVals)}))};
stringToParams = {|str| str.split($-).collect({|bankStr| bankStr.split($,).collect({|val| val.asInt})})};

//TODO: method to load all saved banks from python



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

