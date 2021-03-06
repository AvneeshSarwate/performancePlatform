(
var noteToInd, indToNote, noteToXY, isPadNote, buffers, recSynths, playSynths, recordOnTimes, loopDurTimes, recordMode, f1, f2, loopClocks, break, record_BUTTON, miniOut, padIndToRed, padIndToGreen, record_LIGHT, tempoClock, metronomeSynched, isPlaying, metronomeSync_BUTTON, isSynched, isRecording, startPlaying, stopPlaying, startRecording, stopRecording, syncFlash, red_LIGHT, green_LIGHT, amber_LIGHT, mini, used, abletonLatency, midiOut, pythonOSCport, channelPatternMap, chanBackupPatMap, channelInd, drumTypes, startPattern, playStepGenerator, recieveBackupPattern, stopPattern, patternRead, timeListToDurationList, sendSample, midiChannel, masterTempoClock, tempoClockMap, loopStartFunctions, masterClockBeat, masterClockTempoHandler, playBufQueues, usedBufs, semaphore, pedal, selectedBank, miniProxyNoteOnFunc, miniNoteOffFunc, pedalNoteOnFunc, pedalNoteOffFunc, selectedBankColorStack, miniProxy, miniNoteOnFunc;


miniOut = MIDIOut.newByName("Launchpad Mini", "Launchpad Mini");
miniOut.latency = 0;

mini = MIDIClient.sources.select({|elem| (elem.device == "Launchpad Mini")
	&& (elem.name == "Launchpad Mini")})[0];

miniProxy = MIDIClient.sources.select({|elem| (elem.device == "IAC Driver")
	&& (elem.name == "Bus 5")})[0];

pedal = MIDIClient.sources.select({|elem| (elem.device == "FBV Express Mk II")
	&& (elem.name == "Port 1")})[0];

s.latency = 0.005;

[mini.uid, miniProxy.uid, pedal.uid].postln;

/*
TODO -
continue to tweak latency
   tweak "input latency" from POD by setting buffer playback startpoint x ms after initial recording startpoint
fix recordOnTimes usage - what tempoClock to use? (default vs "tempoClock" var)
things to set via python api
   set number of "count in" beats
   start/end points of loop (referenced by beat)
*/

//quneo control variables
noteToInd = {|x|
	var row = 7- (x / 16).asInt;
	var col = x % 16;
	var retVal = -1;
	if(col < 8, {retVal = row*10 + col});
	retVal.postln;
	retVal
}; //convert note to pad index

noteToXY = {|x| [noteToInd.(x)%16, 7 - (x / 16).asInt]}; //convert note to pad xy (bottom left 0,0)
isPadNote = {|x| noteToInd.(x) != -1};
record_BUTTON = 104;
metronomeSync_BUTTON = 120;
green_LIGHT = 48;
red_LIGHT = 3;
amber_LIGHT = 51;
selectedBankColorStack = List.new();

~abletonLatency = 0;//4.0 * 0.0354; //seconds
~inputLatency = 0;  //skipforward into buffer to counteract input latency

~countIn = 0;  //number of count in metronome hits
~duration = 0;  //preset number of beats to record for

Routine.run {

	s.options.inDevice = "Blue Snowball";
	//s.options.inDevice = "Built-in Microph";
	//s.options.inDevice = "POD HD400";
	s.options.outDevice = "Built-in Output";//"Soundflower (64ch)";

	s.bootSync;

	SynthDef(\recBuf, {|bufnum|
		var input;
		input = SoundIn.ar([0, 1]);
		RecordBuf.ar(input, bufnum, trigger: \trigger.kr(0), loop: 1); //trigger control
	}).add;

	SynthDef(\playBuf, {|out = 0, bufnum|
		var scaledRate, player;
		scaledRate = BufRateScale.kr(bufnum);
		player = PlayBuf.ar(2, bufnum, scaledRate, trigger: \trigger.kr(-1), startPos: \startPosition.kr(1), loop: 1); //trigger control
		Out.ar(out, player)
	}).add;

	s.sync;

	//create - buffs, recBufSynths, playBufSynths with newPause
	buffers = Array.fill(78, {Buffer.alloc(s, s.sampleRate * 30.0, 2)});
	recSynths = Array.fill(78, {|i| Synth.newPaused(\recBuf, [\bufnum, buffers[i]])});
	playSynths = Array.fill(78, {|i| Synth.newPaused(\playBuf, [\out, 0, \bufnum, buffers[i]])});
	playBufQueues = Dictionary.new();
	(0..7).do({|c1| (0..7).do({|c2|
		//aa is 0, which is bottom left
		var ch = "abcdefgh";
		playBufQueues[ch[c1]++ch[c2]] = List.fill(10, {Synth.newPaused(\playBuf, [\out, 0, \bufnum, buffers[(c1*8)+c2]])});
	})});
	s.sync;
};

recordOnTimes = Array.fill(78, {0});
loopDurTimes = Array.fill(78, {10});
loopClocks = Array.fill(78, {TempoClock.new(1)});
recordMode = false;
isPlaying = List.fill(78, {false});
isRecording = List.fill(78, {false});
used = List.fill(78, {false});
isSynched = false;
syncFlash = -1;

break = 0.1;
f1 = {|synth, clock, loopTime, padInd|
	Task({synth.set(\trigger, -1); //this shouldn't be necessary
		s.sync;
		synth.set(\trigger, 1);}).play;
	[padInd, "TRIGGER", clock.beats, tempoClock.beats].postln;
	clock.sched(break, {f2.(synth, clock, loopTime, padInd)});
};
f2 = {|synth, clock, loopTime, padInd|
	synth.set(\trigger, -1);
	clock.sched(loopTime-break, {f1.(synth, clock, loopTime, padInd)});
};

OSCFunc({
	if(isSynched, {
		if(syncFlash > 0,
			{miniOut.noteOn(0, metronomeSync_BUTTON, amber_LIGHT)},
			{miniOut.noteOn(0, metronomeSync_BUTTON, 0)}
		);
		},
		{
			miniOut.noteOn(0, metronomeSync_BUTTON, amber_LIGHT)
		}
	);
	syncFlash = syncFlash * -1;
}, "/masterClockBeat");


miniOut.noteOn(0, metronomeSync_BUTTON, amber_LIGHT);
miniOut.noteOn(0, record_BUTTON, green_LIGHT);
(0..63).do({|i| miniOut.noteOn(0, ((i/8).floor * 16) + (i%8), 0)});

startRecording = {|padInd, note|
	recSynths[padInd].set(\trigger, 1);
	recSynths[padInd].run(true);
	recordOnTimes[padInd] = TempoClock.default.beats;
	miniOut.noteOn(0, note, red_LIGHT);
	["RECORDING START", padInd, tempoClock.beats].postln;
	isRecording[padInd] = true;
	used[padInd] = true;
};

startPlaying = {|padInd, note|
	playSynths[padInd].set(\trigger, 1);
	playSynths[padInd].set(\startPos, ~inputLatency);
	playSynths[padInd].run(true);
	loopClocks[padInd].sched(loopDurTimes[padInd],
		{"FIRS TEMO CLOCK RESET".postln;
			f1.(playSynths[padInd], loopClocks[padInd], loopDurTimes[padInd], padInd)});
	if(used[padInd], {miniOut.noteOn(0, note, green_LIGHT)});
	["PLAY START", padInd, tempoClock.beats].postln;
	isPlaying[padInd] = true;
};

stopRecording = {|padInd, note|
	Task({recSynths[padInd].set(\trigger, -1);
		s.sync;
		recSynths[padInd].run(false);}).play;
	loopDurTimes[padInd] = TempoClock.default.beats - recordOnTimes[padInd];
	miniOut.noteOn(0, note, amber_LIGHT);
	["RECORDING STOP", padInd, tempoClock.beats].postln;
	isRecording[padInd] = false;
	selectedBank= nil;
	selectedBankColorStack.wrapAt(-1)[1] = amber_LIGHT;
};

stopPlaying = {|padInd, note|
	Task({playSynths[padInd].set(\trigger, -1);
		s.sync;
		playSynths[padInd].run(false);}).play;
	loopClocks[padInd].clear;
	if(used[padInd],  {miniOut.noteOn(0, note, amber_LIGHT)});
	["PLAY STOP", padInd, tempoClock.beats].postln;
	isPlaying[padInd] = false;
};

miniProxyNoteOnFunc = {|vel, note, chan, port|
	[note, "NOTE ON"].postln;
	if(isPadNote.(note), {
		var padInd = noteToInd.(note);
		var frozenRecordMode = recordMode;
		var recordStartClick = false;
		var adjustTime = 0;
		var leadIn = 0;
		[isSynched, "IS SYNCHED"].postln;
		if(frozenRecordMode.not,
			{
				if(isSynched,
					{
						var funcToExecute, eventTime;
						if(isPlaying[padInd], {
							funcToExecute = {stopPlaying.(padInd, note)};
							adjustTime = 0 - (~abletonLatency*tempoClock.tempo);
						});
						if(isPlaying[padInd].not, {
							funcToExecute = {startPlaying.(padInd, note)};
							adjustTime = 0 - (~abletonLatency*tempoClock.tempo);
						});

						eventTime = tempoClock.timeToNextBeat + adjustTime;
						tempoClock.sched(eventTime, funcToExecute);

						["LATENCY COMPENSATED", tempoClock.timeToNextBeat,
							tempoClock.timeToNextBeat - (~abletonLatency*tempoClock.tempo),
							tempoClock.beats].postln;
						["SHOULD BE TRUE", (~duration > 0) && recordStartClick, ~duration].postln;
					},
					{startPlaying.(padInd, note)}
				);
			},
			{
				var stackPop = selectedBankColorStack.pop;
				if(stackPop.isNil.not, {
					miniOut.noteOn(0, stackPop[0], stackPop[1]);
				});
				selectedBankColorStack.add([note, if(used[padInd], amber_LIGHT, 0)]);
				selectedBank = note;
				miniOut.noteOn(0, note, green_LIGHT);
			}
		);
	});
};
MIDIFunc.noteOn(miniProxyNoteOnFunc, nil, nil, miniProxy.uid);

miniNoteOnFunc = {|vel, note, chan, port|
	if(note == record_BUTTON, {recordMode = recordMode.not});
	if(note == metronomeSync_BUTTON, {isSynched = isSynched.not});
};
MIDIFunc.noteOn(miniNoteOnFunc, nil, nil, mini.uid);

pedalNoteOnFunc = {|vel, pedalNote, chan, port|
	var note = selectedBank;
	var padInd = noteToInd.(note);
	var frozenRecordMode = recordMode;
	"PEDAL FUNC".postln;
	if((pedalNote == 16) && (vel == 127) && recordMode && selectedBank.isNil.not, {
		var recordStartClick = false;
		var adjustTime = 0;
		var leadIn = 0;
		[isSynched, "IS SYNCHED"].postln;
		if(isSynched,
			{
				var funcToExecute, eventTime;
				["A", frozenRecordMode, isRecording[padInd]].postln;
				if(frozenRecordMode && isRecording[padInd], {funcToExecute = {stopRecording.(padInd, note)}});
				"B".postln;
				if(frozenRecordMode && isRecording[padInd].not, {
					funcToExecute = {startRecording.(padInd, note)};
					adjustTime = ~countIn;
					recordStartClick = true;
				});

				eventTime = tempoClock.timeToNextBeat + adjustTime;
				tempoClock.sched(eventTime, funcToExecute);

				if((~duration > 0) && recordStartClick, {
					"LATE STOP SCHED".postln;
					tempoClock.sched(eventTime+~duration, { stopRecording.(padInd, note); "LATE STOP".postln;});
				});
			},
			{
				if(frozenRecordMode, startRecording.(padInd, note));
		});
	});
	if((pedalNote == 16) && (vel == 0) && recordMode && selectedBank.isNil.not, {
		if(isSynched.not, {stopRecording.(padInd, note)});
	});
};
MIDIFunc.cc(pedalNoteOnFunc, nil, nil, pedal.uid);


MIDIFunc.cc(pedalNoteOffFunc, nil, nil, pedal.uid);

miniNoteOffFunc = {|vel, note, chan, port|
	if(isPadNote.(note) && isSynched.not, {
		var padInd = noteToInd.(note);
		stopPlaying.(padInd, note);
	});
	if(note == record_BUTTON, {
		if(recordMode,
			{miniOut.noteOn(0, record_BUTTON, red_LIGHT)},
			{
				var stackPop = selectedBankColorStack.pop;
				if(stackPop.isNil.not, {
					miniOut.noteOn(0, stackPop[0], stackPop[1]);
				});
				miniOut.noteOn(0, record_BUTTON, green_LIGHT);
			}
	)});
};
MIDIFunc.noteOff(miniNoteOffFunc, nil, nil, miniProxy.uid);






//============================================================================================
//============================================================================================
//============================================================================================
//============================================================================================
// PYDAL CODE



midiOut = MIDIOut.newByName("IAC Driver", "Bus 3");
midiOut.latency = 0;
pythonOSCport = NetAddr("localhost", 34345);

//TODO: implement tempoclock per channel (with synched beats)
//masterTempoClock = TempoClock.new(1);
channelPatternMap = Dictionary();
chanBackupPatMap = Dictionary();
channelInd = Dictionary();
tempoClockMap = Dictionary();
loopStartFunctions = Dictionary();

//TODO - parametrize this
midiChannel = 0;

drumTypes = Dictionary();
drumTypes["~"] = 1;
drumTypes["bd"] = 30;
drumTypes["lt"] = 40;
drumTypes["ht"] = 50;
drumTypes["sn"] = 60;
drumTypes["ho"] = 70;
drumTypes["hc"] = 75;
drumTypes["cr"] = 80;
drumTypes["rd"] = 85;
drumTypes["bot"] = 90;
drumTypes["cp"] = 100;
drumTypes["bin"] = 102;
drumTypes["bend"] = 104;
drumTypes["aud"] = 108;

//msg[1] is the channel being played on
//msg[2] is the string pattern getting played
startPattern = {|msg, time, addr, recvPort|
	//parse string to pattern
	var patternList, loopFrac, ind, startDelay, chanClock;
	["PLAY START", msg[2]].postln;
	patternList = patternRead.(msg[2].asString);

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

	loopStartFunctions[msg[1]] = {chanClock.sched(0, playStepGenerator.(msg[1]))};
};
OSCFunc(startPattern, "/pydalPlay");


playStepGenerator = {|i|
	var playStep = {
		//if list len == 0, exit
		var retVal = nil;
		if(channelPatternMap[i].size != 0, {
			var ind = channelInd[i];
			var patList = channelPatternMap[i];
			var step = patList[ind];
			var dur = step[0];

			step[1].do({|samp| sendSample.(samp, ind)});
			["STEP", i, ind, tempoClockMap[i].beats, step, dur].postln;

			//if 2nd to last step, send request for next pattern TODO: won't work for patterns len 1?
			if(ind == (patList.size-2), {pythonOSCport.sendMsg("/pydalGetUpdate-"++i)});

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


//msg[1] is the channel being played on
//msg[2] is the backup pattern
recieveBackupPattern = {|msg, time, addr, recvPort|
	//parse string and save it to backupmap
	//["GOT BACKUP", msg[2]].postln;
	chanBackupPatMap[msg[1]] = timeListToDurationList.(patternRead.(msg[2].asString));
};
OSCFunc(recieveBackupPattern, "/pydalSendUpdate");


//msg[1] is ind of channel to stop
stopPattern = {|msg, time, addr, recvPort|
	if(channelPatternMap.keys.includes(msg[1]), {channelPatternMap[msg[1]] = []});
	["STOP PATTERN", channelPatternMap.keys.includes(msg[1]), msg[1]].postln;
};
OSCFunc(stopPattern, "/pydalStop");

OSCFunc({|msg, time, addr, recvPort|
	//msg[1] is the new BEAT DURATION (not tempo)
	masterTempoClock = TempoClock.new(1/msg[1], 0);
	t = masterTempoClock;

	//msg[1] is the new BEAT DURATION (not tempo)
	tempoClock = TempoClock.new(1/msg[1], 0);
	t = tempoClock;

	"PYDAL SAMPLE ONESHOT".postln;
}, "/masterClockBeat").oneShot;

//msg[1] is the new BEAT DURATION (not tempo)
masterClockTempoHandler = {|msg, time, addr, recvPort|
	tempoClock.tempo = 1/msg[1].asFloat;
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
	//adding 0.0001 a hack to make sure lists with timestamps like [0, 1] get converted to durations of [1, 1]
	pList.add([(oldList[oldList.size-1][0] + 0.00001).ceil - oldList[oldList.size-1][0], oldList[oldList.size-1][1]]);
	pList
};
"NEW SHIT".postln;

semaphore = Semaphore.new();

//playBufQs - map{pad -> queue of playBufs]
//usedBufs - map[string -> playBuf] (string is concat of sampleString + startTime
usedBufs = Dictionary.new();

sendSample = {|drumStr, patternInd|
	//[drumStr, patternInd].postln;
	if(drumStr.contains("_"),
		{
			//parse sampleString into sample, start, duration
			var bank;
			var start;
			var duration;
			var bufToUse;
			var startSecs;
			//["SAMPLE", drumStr.postln].postln;
			bank = drumStr.asString.split($:)[0];
			start = drumStr.asString.split($:)[1].split($_)[0].asFloat;
			duration = drumStr.asString.split($:)[1].split($_)[1].asFloat - start; //TODO - make sure duration < clip length

			//pull playBuf from appropriate queue
			//semaphore.wait;
			bufToUse = playBufQueues[bank].pop();
			//semaphore.signal;

			startSecs = ~inputLatency + (start*(1/masterTempoClock.tempo));

			//add playBuf to usedBufs
			usedBufs[drumStr++patternInd] = bufToUse;

			//set start of playBuf
			Task({
				//play playBuf
				bufToUse.set(\startPosition, startSecs * s.sampleRate);
				s.sync;
				bufToUse.run(true);
				s.sync;
				bufToUse.set(\trigger, -1); //this shouldn't be necessary
				s.sync;
				bufToUse.set(\trigger, 1);
				s.sync;

				[masterTempoClock.beats, "START SAMPLE", drumStr+patternInd,  startSecs, duration].postln;

			}, masterTempoClock).play;

			//sched "stopPlay" for duration away (endPlay has sampleString+startTime in closure)
			//"stopPlay" stops play, playBuf from usedBuffs, adds it back to appropriate queue
			masterTempoClock.sched(duration, {
				usedBufs[drumStr++patternInd].run(false);
				//semaphore.wait;
				playBufQueues[bank].add(usedBufs[drumStr++patternInd]);
				//semaphore.signal;
				[masterTempoClock.beats,"STOPPED SAMPLE", drumStr, patternInd].postln;
				//[playBufQueues[bank].size].postln;
				nil;
			});
		},
		{

			var drumInd, drumType;
			//"DRUM".postln;
			drumInd = drumStr.split($:)[1];
			drumInd = if(drumInd.isNil, 0, {drumInd.asInteger});
			drumType = drumTypes[drumStr.split($:)[0]].asInteger;

			//todo - send cc map stuff if applicable
			Task({
				midiOut.noteOn(midiChannel, drumType+drumInd); //maybe add velocity based on gain?
				0.001.wait;
				midiOut.noteOff(midiChannel, drumType+drumInd);
			}).play;
		}
	);
};

)


~abletonLatency = 1.0 * 0.0404; //seconds
~inputLatency = ;  //skipforward into buffer to counteract input latency

~countIn = 0;  //number of count in metronome hits
~duration = 0;  //preset number of beats to record for


(
t = TempoClock(1);
t.tempo = 50;
t.tempo



)

