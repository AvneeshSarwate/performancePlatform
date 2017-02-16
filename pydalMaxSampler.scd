//tempoclock with beat set to 1 cycle length
(var midiOut, pythonOSCport, channelPatternMap, chanBackupPatMap, channelInd, drumTypes, startPattern, playStepGenerator, recieveBackupPattern, stopPattern, patternRead, timeListToDurationList, sendSample, midiChannel, masterTempoClock, tempoClockMap, loopStartFunctions, masterClockBeat, masterClockTempoHandler, maxPort, heldHitTasks;

//MIDIClient.init; TODO: move this into masterTempoClock.scd
midiOut = MIDIOut.newByName("IAC Driver", "Bus 3");
midiOut.latency = 0;
pythonOSCport = NetAddr("localhost", 34345);
maxOSCport = NetAddr("localhost", 5432);

//TODO: implement tempoclock per channel (with synched beats)
//masterTempoClock = TempoClock.new(1);
channelPatternMap = Dictionary();
chanBackupPatMap = Dictionary();
channelInd = Dictionary();
tempoClockMap = Dictionary();
loopStartFunctions = Dictionary();
heldHitTasks = Dictionary();

//TODO - parametrize this
midiChannel = 0;

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

			step[1].do({|samp| sendSample.(samp)});
			//["STEP", i, ind, tempoClockMap[i].beats%1, step].postln;

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



sendSample = {|drumStr|
    var bank, start, end, duration, bufToUse, startSecs, banksToTurnOff, bufferOffset;
    //["SAMPLE", drumStr.postln].postln;
    bank = "abcd".indexOf(drumStr.asString.split($:)[0]) + 1;
    start = drumStr.asString.split($:)[1].split($_)[0].asFloat;
    end = drumStr.asString.split($:)[1].split($_)[1];
    duration = if(end.isNil.not && (end > start), end.asFloat - start, nil);

    //turn of other buffers (all buffers if end < start, otherwise start buffer)
    //erase scheduled turn offs (all buffers if end < start, otherwise start buffer)
    banksToTurnOff = if(end < start, (1..4), [bank]);
    banksToTurnOff.do({|i|
        maxPort.sendMsg("/sampLoop/" ++ i ++ "/playStart", 0, 0);
        if(heldHitTasks[i].isNil.not, {
            heldHitTasks[i].stop;
            heldHitTasks[i].free;
            heldHitTasks[i] = nil;
        });
    });

    //play this buffer
    // 1/(beats/sec) * beats * ms/s
    bufferOffset = 1/(masterTempoClock.tempo/60) * start * 1000;
    //TODO max - will having speed=1 conflict with LFO-set speed?
    maxPort.sendMsg("/sampLoop/" ++ bank ++ "/playStart", 1, bufferOffset);

    //schedule turn off if needed
    if(duration.isNil.not, {
        heldHitTasks[bank] = Task({
            duration.wait;
            maxPort.sendMsg("/sampLoop/" ++ bank ++ "/playStart", 0, 0);
        }, masterTempoClock).play;
    });

};

)
//===========================================================================
//scratch code below
(
d = Dictionary.new;
d.includes(5);
)

(
t = TempoClock(1);
t.beats.postln;
j = 5;
(1..10000).do({|i| j = i*3});
t.beats.postln;
j
)

(
var patternSplit = {|patternStr|
	var patternList = List.new;
	patternStr.split($;).do({|s|
		var step = s.split($-);
		var time = step[0].asFloat;
		var sampSet = Set.newFrom(step[1].split($,));
		step[0].postln;
		step[1].postln;
		patternList.add([time, sampSet]);
	});
	patternList
};
b = patternSplit.("0.6-a,b;0.8-c");
"0.6-a,b;0.8-c".split($;).postln;
"break".postln;
b.do({|e| [e[0], e[1], e.class].postln});
b.size.postln;
nil
)
"0.6".asFloat
(
b = [1, 3];
Set(b)
)