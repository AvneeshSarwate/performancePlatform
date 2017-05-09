(var miniOut, mini, pythonOSCport, noteToInd, noteToXY, isPadNote, record_BUTTON, green_LIGHT, red_LIGHT, amber_LIGHT, savedScenes, recording, noteOnFunc, loadSavedSceneLights, indToNote, miniFwdOut, noteOffFunc, isChordNote, ccFunc, utilityButtons, isSceneNote, chordButtonChanMap, numChordPadsPlaying, releaseChords, releaseChords_BUTTON, tempoClock, loopRecordBuffer, recordingLoop, metronomeFunc, bankNotes, recordingStartBeat, bankInfo;

//TODO - add a "scene stack" in python in case you accidentally
//pull up an old scene before saving the one you're working on

//TODO - add a "load file" way to populate the correct lights

miniOut = MIDIOut.newByName("Launchpad Mini", "Launchpad Mini");
miniOut.latency = 0;
miniFwdOut = MIDIOut.newByName("IAC Driver", "Bus 5");
miniFwdOut.latency = 0;
pythonOSCport = NetAddr("localhost", 13371);

utilityButtons = (24,40..120);
numChordPadsPlaying = 0;
releaseChords = false;

mini = MIDIClient.sources.select({|elem| (elem.name == "Launchpad Mini")
	&& (elem.device == "Launchpad Mini")})[0];

//bottom left is 00
noteToInd = {|x|
	var row = 7 - (x / 16).asInt;
	var col = x % 16;
	var retVal = -1;
	if(col < 8, {retVal = row*10 + col});
	retVal
}; //convert note to pad index

indToNote = {|x|
	var note = -1;
	var col = x % 10;
	var row = ((x - col)/10).asInt;
	var midiRow = (7-row) * 16;
	if((col < 8) && (row < 8), {note = midiRow + col});
	note;
};

isPadNote = {|x| noteToInd.(x) != -1};
isChordNote = {|x| isPadNote.(x) && (noteToInd.(x) >= 20)}; //bottom two rows are for scenes
isSceneNote = {|x| isPadNote.(x) && (noteToInd.(x) < 20)};
record_BUTTON = 8;
green_LIGHT = 48;
red_LIGHT = 3;
amber_LIGHT = 51;
releaseChords_BUTTON = 24;

loopRecord_BUTTON = 40;
//states for recordLoop: 0 - not recording (green), 1 - recording to start on next beat
//2 - recording (red flash), 3 - buffer on deck (green flash)
recordingLoop = 0;
loopRecordBuffer = List();
metronomeFunc = {
    if(recordingLoop == 1, {
        recordingLoop = 2;
        recordingStartBeat = tempoClock.beats;
    });
    Task({
        miniOut.noteOn(0, loopRecord_BUTTON, red_LIGHT);
        (0..3).do({|i|
            if(bankInfo[i][0], {miniOut.noteOn(0, bankNotes[i], green_LIGHT)})
        });
        0.5.wait;
        miniOut.noteOn(0, loopRecord_BUTTON, 0);
        (0..3).do({|i|
            if(bankInfo[i][0], {miniOut.noteOn(0, bankNotes[i], 0)})
        });
        0.49.wait;
        (0..3).do({|i|
            if(bankInfo[i][0], {miniOut.noteOn(0, bankNotes[i], green_LIGHT)})
        });
    }, tempoClock).play;
    1;
};
createLoopTask = {|oldRecBuf, startBeat, endBeat|
    var recBuf = List.newFrom(oldRecBuf);
    var timeAfterLastHit;
    var newTask;

    recBuf.do({|hit| if(hit[0] < startBeat, {hit[0] = startBeat}) });

    if(~truncateLoop,
		{timeAfterLastHit = (recBuf[recBuf.size-1][0].ceil - recBuf[recBuf.size-1][0])},
		{timeAfterLastHit = endBeat - recBuf[recBuf.size-1][0]}
	);

    (recBuf.size-1..1).do({|i| recBuf[i][0] = recBuf[i][0] - recBuf[i-1][0]});
	recBuf[0][0] = recBuf[0][0] - startBeat;

    recBuf.add([timeAfterLastHit]);

    newTask = Task({
        var ind = 0;
        {
            recBuf[ind][0].wait;
            if(recBuf.size > 1, {pythonOSCport.sendRaw(refBuf[ind][1..].asArray.asRawOSC)});
            ind = (ind+1) % recBuf.size;
        }.loop;
    }, tempoClock);
    newTask.play;
    newTask
};
bankNotes = [72, 88, 104, 120];
bankInfo = [[false, nil], [false, nil], [false, nil], [false, nil]];

recordingStartBeat = 0;
recordingEndBeat = 0;
tempLoopTask = Task();

savedScenes = Dictionary.new();
recording = false;

chordButtonChanMap = Dictionary.new;
(0..128).do({|i| chordButtonChanMap[i] = ""});
(20..49).do({|i| chordButtonChanMap[i] = "-0"});
(50..79).do({|i| chordButtonChanMap[i] = "-1"});

miniOut.noteOn(0, record_BUTTON, green_LIGHT);
miniOut.noteOn(0, loopRecord_BUTTON, green_LIGHT);
miniOut.noteOn(0, releaseChords_BUTTON, 0);
(0..63).do({|i| miniOut.noteOn(0, ((i/8).floor * 16) + (i%8), 0)});


//TODO: move variable instations to near the functions that use them
OSCFunc({|msg, time, addr, recvPort|
	//msg[1] is the new BEAT DURATION (not tempo)
	tempoClock = TempoClock.new(1/msg[1], 0);
    tempoClock.schedAbs(1, metronomeFunc);
}, "/masterClockBeat").oneShot;

//msg[1] is the new BEAT DURATION (not tempo)
//msg[2] is whether the beat is being realigned
masterClockTempoHandler = {|msg, time, addr, recvPort|
	tempoClock.tempo = 1/msg[1].asFloat;
	if(msg[2].asBoolean, {tempoClock.beats = tempoClock.beats.floor + 1});
};
OSCFunc(masterClockTempoHandler, "/masterClockTempo");


noteOnFunc = {|vel, note, chan, port|
	["NOTE ON ENTERED", note].postln;
	if(note == loopRecord_BUTTON,{
        if(recordLoop == 0, {recordLoop = 1});
        if(recordLoop == 3, {
            loopRecordBuffer.clear;
            recordLoop = 0;
            tempLoopTask.stop;
            tempLoopTask.free;
            miniOut.noteOn(0, loopRecord_BUTTON, green_LIGHT);
        });
        if(recordLoop == 2, {
            recordingEndBeat = tempoClock.beats.ceil;
            tempLoopTask = createLoopTask.(loopRecordBuffer, recordingStartBeat, recordingEndBeat);
            recordLoop = 3;
        });
	});
    if(bankNotes.includes(note), {
        var selectedBank = bankInfo[bankNotes.indexOf(note)];
        if(recordLoop == 2,
            {
                tempoClock.sched(tempoClock.timeToNextBeat, {
                    if(selectedBank[1].isNil.not, {
                        selectedBank[1].stop;
                        selectedBank[1].free;
                    })
                    selectedBank[1] = tempLoopTask;
                    selectedBank[0] = true;
                });
            },
            {
                if(selectedBank[1].isNil.not, {
                    if(selectedBank[0] ,
                        {tempoClock.sched(tempoClock.timeToNextBeat, {selectedBank[1].stop; selectedBank[0] = false})},
                        {tempoClock.sched(tempoClock.timeToNextBeat, {selectedBank[1].start; selectedBank[0] = true})}
                    );
                });
            };
        );
    });
    if(note == record_BUTTON,{
		recording = recording.not;
		miniOut.noteOn(0, record_BUTTON, if(recording, red_LIGHT, green_LIGHT));
	});
    if(note == releaseChords_BUTTON, {
       releaseChords = releaseChords.not;
        miniOut.noteOn(0, releaseChords_BUTTON, if(releaseChords, green_LIGHT, 0));
    });
	if(isPadNote.(note),{
        var ind = noteToInd.(note);
		if(isChordNote.(note), {
			if(recording, {
                pythonOSCport.sendMsg("/saveChord"++chordButtonChanMap[ind], ind);
				miniOut.noteOn(0, note, amber_LIGHT);
				savedScenes[note] = true;
			},
			{
				if(savedScenes[note].isNil.not, {
                    pythonOSCport.sendMsg("/playChord"++chordButtonChanMap[ind], ind);
                    if(recordingLoop == 1, {loopRecordBuffer.add([tempoClock.beats, "/playChord"++chordButtonChanMap[ind], ind])});
                });
                if(releaseChords, {numChordPadsPlaying = numChordPadsPlaying+1});
			})
        });
        if(isSceneNote.(note), {
            if(recording, {
                pythonOSCport.sendMsg("/saveScene", ind);
                miniOut.noteOn(0, note, amber_LIGHT);
                savedScenes[note] = true;
            },
            {
                if(savedScenes[note].isNil.not, {
                    pythonOSCport.sendMsg("/playScene", ind);
                });
            })
        });
    });
    if(utilityButtons.includes(note), {
        pythonOSCport.sendMsg("/utilityButton", utilityButtons.indexOf(note), if(recording, 1, 0));
        if(recording, {miniOut.noteOn(0, note, amber_LIGHT)});
    });
};
MIDIFunc.noteOn(noteOnFunc, nil, nil, mini.uid);

noteOffFunc = {|vel, note, chan, port|
	if(isChordNote.(note),
        {
            if(recording.not && releaseChords, {numChordPadsPlaying = numChordPadsPlaying-1});
            ["NUM CHORDS PLAYING", numChordPadsPlaying].postln;
            if((numChordPadsPlaying == 0) && releaseChords && recording.not, {
                pythonOSCport.sendMsg("/stopChord"++chordButtonChanMap[noteToInd.(note)]);
                if(recordingLoop == 1, {loopRecordBuffer.add([tempoClock.beats, "/stopChord"++chordButtonChanMap[noteToInd.(note)]])});
                ["CHORD OFF", chordButtonChanMap[noteToInd.(note)]].postln;
            });
        },
        {miniFwdOut.noteOff(0, note, vel);}
    );
};
MIDIFunc.noteOff(noteOffFunc, nil, nil, mini.uid);

ccFunc = {|vel, note, chan, port|
	var ccInd = note - 104;
	["TOP ROW", ccInd, vel];
	pythonOSCport.sendMsg("/miniLaunchpadTopRow", ccInd, vel);
};
MIDIFunc.cc(ccFunc, nil, nil, mini.uid);

loadSavedSceneLights = {|msg, time, addr, recvPort|
	msg[1].asString.split($,)
	.collect({|str| str.asInt})
	.do({|ind|
		var note = indToNote.(ind);
		if(ind > 0,
			{
				savedScenes[note] = true;
				miniOut.noteOn(0, note, amber_LIGHT);
			},
			{
				savedScenes[note] = true;
				miniOut.noteOn(0, note, 0);
			}
		);
	});
};
OSCFunc(loadSavedSceneLights, "/loadChords");

loadSavedSceneLights = {|msg, time, addr, recvPort|
	msg[1].asString.split($,)
	.collect({|str| str.asInt})
	.do({|ind|
		var note = indToNote.(ind);
		if(ind > 0,
			{
				savedScenes[note] = true;
				miniOut.noteOn(0, note, amber_LIGHT);
			},
			{
				savedScenes[note] = true;
				miniOut.noteOn(0, note, 0);
			}
		);
	});
};
OSCFunc(loadSavedSceneLights, "/loadScenes");
)

(
var indToNote = {|x|
	var note = -1;
	var col = x % 10;
	var row = ((x - col)/10).asInt;
	var midiRow = (7-row) * 16;
	if((col < 8) && (row < 8), {note = midiRow + col});
	note;
};
indToNote.(7);
)