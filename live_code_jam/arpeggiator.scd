(//tempoclock with beat set to 1 cycle length
var midiOut, pythonOSCport, channelPatternMap, chanBackupPatMap, channelInd, drumTypes, startPattern, playStepGenerator, recieveBackupPattern, stopPattern, patternRead, timeListToDurationList, sendSample, masterTempoClock, tempoClockMap, loopStartFunctions, masterClockBeat, masterClockTempoHandler, noteForwardHandler, channelToMidiChannel, onNotes, onNotesList, channelToMidi;

//MIDIClient.init; TODO: move this into masterTempoClock.scd
midiOut = MIDIOut.newByName("IAC Driver", "Bus 2");
midiOut.latency = 0;
pythonOSCport = NetAddr("localhost", 34345);

//TODO: implement tempoclock per channel (with synched beats)
//masterTempoClock = TempoClock.new(1);
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
			chanClock = TempoClock.new(masterTempoClock.tempo, masterTempoClock.beats);
			tempoClockMap[msg[1]] = chanClock;
			chanClock.beats = masterTempoClock.beats;
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
	masterTempoClock = TempoClock.new(1/msg[1], 0);
	t = masterTempoClock;
};
OSCFunc(f, "/masterClockBeat").oneShot;

//msg[1] is the new BEAT DURATION (not tempo)
masterClockTempoHandler = {|msg, time, addr, recvPort|
	//(0..3).do({|i| metronomeClocks[i].tempo = 1/msg[1].asFloat})
	masterTempoClock.tempo =  1/msg[1].asFloat;
	tempoClockMap.values.do({|clock| clock.tempo = 1/msg[1].asFloat});
};
OSCFunc(masterClockTempoHandler, "/masterClockTempo");

//msg[1] is the new BEAT DURATION (not tempo)
masterClockBeat = {|msg, time, addr, recvPort|
	loopStartFunctions.keys.do({|key|
		if(loopStartFunctions[key] != nil, {
			["START", masterTempoClock.beats].postln;
			loopStartFunctions[key].();
			loopStartFunctions[key] = nil;
		})
	});
	//["PYDAL BEAT", masterTempoClock.beats].postln;
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
			midiOut.noteOn(midiChannel, newNote, newNoteVel); //maybe add velocity based on gain?
			0.25.wait;
			midiOut.noteOff(midiChannel, newNote, newNoteVel);
		}).play;
	});
};

)
//===========================================================================
//scratch code below
