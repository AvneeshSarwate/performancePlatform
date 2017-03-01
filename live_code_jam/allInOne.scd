(
var masterTempoClock, broadcastOSCport;
var keyboardDict, oscOut, useArpeggiator, midiOutKeys, keyboardKeys, heldKeys;
var midiOutPydal, pythonOSCport, channelPatternMap, chanBackupPatMap, channelInd, drumTypes, startPattern, playStepGenerator, recieveBackupPattern, stopPattern, patternRead, timeListToDurationList, sendSample, arpTempoClock, tempoClockMap, loopStartFunctions, masterClockBeat, masterClockTempoHandler, noteForwardHandler, channelToMidiChannel, onNotes, onNotesList, channelToMidi;

MIDIClient.init;
MIDIIn.connectAll;

masterTempoClock = TempoClock.new(1);
broadcastOSCport = NetAddr("localhost", 57120);

masterTempoClock.sched(0, {broadcastOSCport.sendMsg("/masterClockBeat", masterTempoClock.beatDur); 1});

//msg[1] is the new BEAT DURATION (not tempo)
//msg[2] is whether the beat is being realigned
OSCFunc({|msg, time, addr, recvPort|
	masterTempoClock.tempo = 1/msg[1].asFloat;
	broadcastOSCport.sendMsg("/masterClockTempo", msg[1].asFloat, msg[2].asBoolean)
}, "/uploadTempo");

keyboardDict = Dictionary.new();
oscOut = NetAddr("localhost", 34567);
useArpeggiator = true;
midiOutKeys = MIDIOut.newByName("IAC Driver", "Bus 2");
midiOutKeys.latency = 0;
heldKeys = Set.new();

m = midiOutKeys;

k = keyboardDict;
k["q"] = 60;
k["2"] = 61;
k["w"] = 62;
k["3"] = 63;
k["e"] = 64;
k["r"] = 65;
k["5"] = 66;
k["t"] = 67;
k["6"] = 68;
k["y"] = 69;
k["7"] = 70;
k["u"] = 71;
k["i"] = 72;
k["9"] = 71;
k["o"] = 74;
k["0"] = 73;
k["p"] = 76;

k["z"] = 45;
k["s"] = 46;
k["x"] = 47;
k["c"] = 48;
k["f"] = 49;
k["v"] = 50;
k["g"] = 51;
k["b"] = 52;
k["n"] = 53;
k["j"] = 54;
k["m"] = 55;
k["k"] = 56;
k[","] = 57;
k["l"] = 58;
k["."] = 59;

keyboardKeys = k.keys;


w = Window.new("I catch keystrokes");
w.view.keyDownAction = {|view, char, modifiers, unicode, keycode|
	if(char.asString == "`", {
		useArpeggiator = useArpeggiator.not;
	});

	if(keyboardKeys.includes(char.asString) && heldKeys.includes(char).not, {
		if(useArpeggiator,
			{
				oscOut.sendMsg("/sendToArpeggiator", 0, keyboardDict[char.asString], 64, "on");
				"ON SENT".postln;
			},
			{midiOutKeys.noteOn(0, keyboardDict[char.asString], 64)}
		);
		heldKeys.add(char)
	});
};

w.view.keyUpAction = {|view, char, modifiers, unicode, keycode|
	if(keyboardKeys.includes(char.asString), {
		if(useArpeggiator,
			{oscOut.sendMsg("/sendToArpeggiator", 0, keyboardDict[char.asString], 64, "off")},
			{midiOutKeys.noteOff(0, keyboardDict[char.asString], 64)}
		);
	});
	heldKeys.remove(char);
};
w.front;


//MIDIClient.init; TODO: move this into masterTempoClock.scd
midiOutPydal = MIDIOut.newByName("IAC Driver", "Bus 2");
midiOutPydal.latency = 0;
pythonOSCport = NetAddr("localhost", 34345);

//TODO: implement tempoclock per channel (with synched beats)
//arpTempoClock = TempoClock.new(1);
channelPatternMap = Dictionary();
chanBackupPatMap = Dictionary();
channelInd = Dictionary();
channelToMidiChannel = Dictionary();
tempoClockMap = Dictionary();
loopStartFunctions = Dictionary();

//TODO: THIS (onNotes, onNotesList) WILL NOT WORK FOR MULTIPLE MIDI CHANNELS AT ONCE (the rest probably will, but check it)
onNotes = Dictionary();
onNotesList = List();

//msg is [addr, note, vel, onOff]
noteForwardHandler = {|msg, time, addr, recvPort|
	["onOff message", msg].postln;
	if(msg[3].asString == "on",
		{
			onNotes[msg[1].asInt] = msg[2].asInt;
			onNotesList.add(msg[1].asInt);
			onNotesList.sort();
			["FWD ON", msg[1].asInt].postln;
		},
		{
			onNotes.removeAt(msg[1].asInt);
			onNotesList.remove(msg[1].asInt);
			onNotesList.sort();
			["FWD OFF", msg[1].asInt].postln;
		}
	);
};
OSCFunc(noteForwardHandler, "/forwardNotes");


//msg[1] is the pydal channel being played on
//msg[2] is the string pattern getting played
//msg[3] is the midi channel being played on
startPattern = {|msg, time, addr, recvPort|
	//parse string to pattern
	var patternList, loopFrac, ind, startDelay, chanClock;
	["PLAY START", msg[2]].postln;
	patternList = patternRead.(msg[2].asString);
	channelToMidiChannel[msg[1]] = msg[3].asInt;

	//save pattern to map
	channelPatternMap[msg[1]] = timeListToDurationList.(patternList);
	chanBackupPatMap[msg[1]] = [];

	//create channel tempo clock if needed
	if(tempoClockMap.keys.includes(msg[1]).not,
		{
			chanClock = TempoClock.new(arpTempoClock.tempo, arpTempoClock.beats);
			tempoClockMap[msg[1]] = chanClock;
			chanClock.beats = arpTempoClock.beats;
		},
		{chanClock = tempoClockMap[msg[1]]}
	);

	chanClock.clear;

	tempoClockMap.values.do({|v| v.beats.postln;});

	/*channelInd[msg[1]] = 0;
	chanClock.sched(chanClock.timeToNextBeat, playStepGenerator.(msg[1]));*/

	channelInd[msg[1]] = 0;

	//give it 1 milisecond to make sure the first note for onNotes has been recieved
	chanClock.sched(0.001, playStepGenerator.(msg[1]));
};
OSCFunc(startPattern, "/arpeggiatorPlay");


playStepGenerator = {|i|
	var playStep = {
		//if list len == 0, exit
		var retVal = nil;
		if(channelPatternMap[i].size != 0, {
			var ind = channelInd[i];
			var patList = channelPatternMap[i];
			var step = patList[ind];
			var dur = step[0];

			step[1].do({|samp| sendSample.(samp, channelToMidiChannel[i], ind)});
			//["STEP", i, ind, tempoClockMap[i].beats%1, step].postln;

			//if 2nd to last step, send request for next pattern TODO: won't work for patterns len 1?
			if(ind == (patList.size-2), {pythonOSCport.sendMsg("/arpeggiatorGetUpdate-"++i)});

			//if last step (or < 20 ms from end?), set backupPat to actual pattern
			if(ind == (patList.size-1), {
				//"DID BACKUP".postln;
				channelPatternMap[i] = chanBackupPatMap[i]
			});

			//update indexes appropriately
			channelInd[i] = (ind+1)%patList.size;

			//return (d) - i.e. schedule next step on channel
			retVal = dur;
			//["RETVAL1", retVal].postln;
		});
		//["RETVAL2", retVal].postln;
		retVal
	};
	playStep
};


//msg[1] is the pydal channel being played on
//msg[2] is the backup pattern
recieveBackupPattern = {|msg, time, addr, recvPort|
	//parse string and save it to backupmap
	//["GOT BACKUP", msg[2]].postln;
	chanBackupPatMap[msg[1]] = timeListToDurationList.(patternRead.(msg[2].asString));
};
OSCFunc(recieveBackupPattern, "/arpeggiatorSendUpdate");


//msg[1] is ind of channel to stop
stopPattern = {|msg, time, addr, recvPort|
	if(channelPatternMap.keys.includes(msg[1]), {channelPatternMap[msg[1]] = []});
	["STOP PATTERN", channelPatternMap.keys.includes(msg[1]), msg[1]].postln;
};
OSCFunc(stopPattern, "/arpeggiatorStop");

f = {|msg, time, addr, recvPort|
	//msg[1] is the new BEAT DURATION (not tempo)
	arpTempoClock = TempoClock.new(1/msg[1], 0);
	t = arpTempoClock;
};
OSCFunc(f, "/masterClockBeat").oneShot;

//msg[1] is the new BEAT DURATION (not tempo)
masterClockTempoHandler = {|msg, time, addr, recvPort|
	//(0..3).do({|i| metronomeClocks[i].tempo = 1/msg[1].asFloat})
	arpTempoClock.tempo =  1/msg[1].asFloat;
	tempoClockMap.values.do({|clock| clock.tempo = 1/msg[1].asFloat});
};
OSCFunc(masterClockTempoHandler, "/masterClockTempo");
cos(0*pi)
//msg[1] is the new BEAT DURATION (not tempo)
masterClockBeat = {|msg, time, addr, recvPort|
	loopStartFunctions.keys.do({|key|
		if(loopStartFunctions[key] != nil, {
			["START", arpTempoClock.beats].postln;
			loopStartFunctions[key].();
			loopStartFunctions[key] = nil;
		})
	});
	//["PYDAL BEAT", arpTempoClock.beats].postln;
};
OSCFunc(masterClockBeat, "/masterClockBeat");


patternRead = {|patternStr|
	var patternList = List.new;
	patternStr.split($;).do({|s|
		var step = s.split($-);
		var time = step[0].asFloat;
		var sampSet = Set.newFrom(step[1].split($,));
		patternList.add([time, sampSet]);
	});
	patternList
};

timeListToDurationList = {|oldList|
	var pList = List.new;
	if(oldList.size > 1,
		{
			(0..oldList.size-2).do({|i|
				pList.add([oldList[i+1][0] - oldList[i][0], oldList[i][1]]);
			});

	});
	pList.add([oldList[oldList.size-1][0].ceil - oldList[oldList.size-1][0], oldList[oldList.size-1][1]]);
	pList
};

sendSample = {|noteStr, midiChannel, ind|
	[noteStr, ind, noteStr.isNil].postln;
	if(onNotesList.size > 0, {
		var noteInd = noteStr.asInt;
		var newNote = onNotesList[noteInd % onNotesList.size];
		var newNoteVel = onNotes[newNote];

		//todo - send cc map stuff if applicable
		Task({
			midiOutPydal.noteOn(midiChannel, newNote, newNoteVel); //maybe add velocity based on gain?
			0.25.wait;
			midiOutPydal.noteOff(midiChannel, newNote, newNoteVel);
		}).play;
	});
};
)
