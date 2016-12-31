(var abletonOut, sliderVals, paramsToString, stringToParams, savedBanks, ipadPort, pushCurrentSliderVals, sliderValsToString, stringToSliderVals, pythonPort, savedBanksToString, stringToSavedBanks, numSliders, followHandler, tempoClock;


abletonOut = MIDIOut.newByName("IAC Driver", "Bus 4");
ipadPort = NetAddr("192.168.0.25", 9000);
pythonPort = NetAddr("localhost", 13371);
tempoClock = TempoClock(1);

sliderVals = List.fill(4, {List.fill(12, {0})});
savedBanks = List.fill(4, { List.fill(4, {List.fill(12, {0})}) });

numSliders = 48;

//msg[1] is the new BEAT DURATION (not tempo)
//msg[2] is whether the beat is being realigned
masterClockTempoHandler = {|msg, time, addr, recvPort|
	tempoClock.tempo = 1/msg[1].asFloat;
	if(msg[2].asBoolean, {tempoClock.beats = tempoClock.beats.floor + 1});
};
OSCFunc(masterClockTempoHandler, "/masterClockTempo");
//TODO: move variable instations to near the functions that use them
OSCFunc({|msg, time, addr, recvPort|
	//msg[1] is the new BEAT DURATION (not tempo)
	tempoClock = TempoClock.new(1/msg[1], 0);
	t = tempoClock;
	tempoClock.schedAbs(1, metronomeFunc);
	"MULTILOOP ONE SHOT".postln;
}, "/masterClockBeat").oneShot;

/*pushCurrentSliderVals = {
	"FUNCTION pushCurrentSliderVals".postln;
	(0..11).do({|i| (0..3).do({|bank|
		abletonOut.control(0, (bank*12)+i, sliderVals[bank][i]);
		//("/faders/" ++ bank.asString ++ "/" ++ (i+1).asString).postln;
		ipadPort.sendMsg("/faders/" ++ bank.asString ++ "/" ++ (i+1).asString, sliderVals[bank][i]);
	})});
	"pushCurrentSliderVals banks".postln;
	(0..3).do({|bank| (0..3).do({|slot|
		var bankOn;
		if(savedBanks[bank][slot].sum > 0, {bankOn = 1}, {bankOn = 0});
		"post check".postln;
		ipadPort.sendMsg("/saveBank/" ++ bank.asString ++ "/1/" ++ (slot+1).asString, bankOn);
	})});
};*/

(0..3).do({|i| (0..2).do({|j|

	//slider hanlders msg[1] is val
	OSCFunc.newMatching({|msg, time, addr, recvPort|
		var bank = msg[0].asString.split($/)[2].asInt;
		var copy = msg[0].asString.split($/)[3].asInt;
		var val = [(msg[1].asFloat*127).round, (msg[2].asFloat*127).round];
		var ccNum = numSliders + (((bank*4) + copy)*2);
		val.postln;
		sliderVals[bank][copy] = val;
		abletonOut.control(0, ccNum, val[0]);
		abletonOut.control(0, ccNum+1, val[1]);
        //forward (padXY(0-11), xVal, yVal) to python
        pythonPort.sendMsg("/xyToPython", ((bank*4) + copy), val[0], val[1]);
	}, "/space/" ++ i.asString ++ "/" ++ j.asString);

	/*OSCFunc.newMatching({|msg, time, addr, recvPort|
		var bank = msg[0].asString.split($/)[2].asInt;
		var slot = msg[0].asString.split($/)[4].asInt - 1;
		var val = msg[1].asFloat.round;
		if(val == 0,
			{}, //TODO: do anything for "erasing" a parameter bank slot?
			{savedBanks[bank][slot] = List.newFrom(sliderVals[bank])},
		);

		//TODO: send to python
		pythonPort.sendMsg("/faderSettingSave", bank, slot, sliderVals[bank].join(","));

	}, "/saveBank/" ++ i.asString ++ "/1/" ++ j.asString);
	//extra /1/ because verticla control where addresses are /widgetBaseAddr/x/y

	OSCFunc.newMatching({|msg, time, addr, recvPort|
		var bank = msg[0].asString.split($/)[2].asInt;
		var slot = msg[0].asString.split($/)[4].asInt - 1;
		var val = msg[1].asFloat.round;
		["PLAYBANK", bank, slot, val, savedBanks[bank][slot].asList.class.name].postln;
		if(val != 0, {
			sliderVals[bank] = List.copyInstance(savedBanks[bank][slot].asList);
			pushCurrentSliderVals.();
		});
	}, "/playBank/" ++ i.asString ++ "/1/" ++ j.asString);*/
})});

//msg is padXY, xVal, yVal, delay
followHandler = {|msg, time, addr, recvPort|
    tempoClock.sched(msg[4].asFloat, {
        var ccNum = numSliders + (msg[1].asInt*2);
        abletonOut.control(0, ccNum, msg[2]);
		abletonOut.control(0, ccNum+1, msg[3]);
        ipadPort.sendMsg("/space/" ++ (msg[1].asInt/4).floor ++ "/" ++ (msg[1].asInt/4)%4, msg[2]/127, msg[3]/127);
    });
};

//msg[1] is string encoding of params
/*OSCFunc({|msg, time, addr, recvPort|
	var params = stringToParams.(msg[1].asString);
	(0..3).do({|i| (0..11).do({|j|
		ipadPort.sendMsg("/faders/" ++ i.asString ++ "/" ++ (j+1).asString, params[i][j]);
		abletonOut.control(0, (i*4)+j, params[i][j]);
	})});
}, "/loadParams");

savedBanksToString = {|params| params.collect({|bank| bank.collect({|slotVals| slotVals.join(",")}).join(".")}).join("-")};
stringToSavedBanks = {|str| str.split($-).collect({|bankStr| bankStr.split($.).collect({|slotStr| slotStr.split($,).collect({|val| val.asInt})})})};

sliderValsToString = {|bank| bank.collect({|faderVals| faderVals.join(",")}).join(".")};
stringToSliderVals = {|bankStr| bankStr.split($.).collect({|faderStr| faderStr.split($,).collect({|val| val.asInt})})};*/

//TODO: method to load all saved banks from python
//msg[1] is sceneInd for which the vals are requested
/*OSCFunc({|msg, time, addr, recvPort|
	"SENDING CURRENT FADERS".postln;
	pythonPort.sendMsg("/getCurrentFaderVals", sliderValsToString.(sliderVals), msg[1].asInt);
}, "/getCurrentFaderVals");*/

//msg[1] is savedBanks in string form
//msg[2] is sliderVals in string form
/*OSCFunc({|msg, time, addr, recvPort|
	savedBanks = stringToSavedBanks.(msg[1].asString);
	sliderVals = stringToSliderVals.(msg[2].asString);
	pushCurrentSliderVals.();
	"FADERS FROM SCENE LOADED".postln;
}, "/loadSceneFaders");*/


)

(
//FUNCTION TO "TWIDDLE KNOB" FOR AN XY-PAD
// 0 for X, 1 for Y in third arg
var twiddle = {|inst, padNum, xy|
	var midiOut;
	var ccNum = 48 + (((inst*4) + padNum)*2);


	midiOut = MIDIOut.newByName("IAC Driver", "Bus 4");
	midiOut.latency = 0;

	Task({
		midiOut.control(0, ccNum+xy, 0);
		0.01.wait;
		midiOut.control(0, ccNum+xy, 127);
	}).play;
};
twiddle.value(3, 2, 0);
)

