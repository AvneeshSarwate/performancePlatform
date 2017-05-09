(var miniOut, mini, pythonOSCport, noteToInd, noteToXY, isPadNote, record_BUTTON, green_LIGHT, red_LIGHT, amber_LIGHT, savedScenes, recording, noteOnFunc, loadSavedSceneLights, indToNote, miniFwdOut, noteOffFunc, isChordNote, ccFunc, utilityButtons, isSceneNote, chordButtonChanMap;



//TODO - add a "scene stack" in python in case you accidentally
//pull up an old scene before saving the one you're working on

//TODO - add a "load file" way to populate the correct lights

miniOut = MIDIOut.newByName("Launchpad Mini", "Launchpad Mini");
miniOut.latency = 0;
miniFwdOut = MIDIOut.newByName("IAC Driver", "Bus 5");
miniFwdOut.latency = 0;
pythonOSCport = NetAddr("localhost", 13371);

utilityButtons = (24,40..120);

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

savedScenes = Dictionary.new();
recording = false;

chordButtonChanMap = Dictionary.new;
(0..128).do({|i| chordButtonChanMap[i] = ""});
(20..49).do({|i| chordButtonChanMap[i] = "-0"});
(50..79).do({|i| chordButtonChanMap[i] = "-1"});

miniOut.noteOn(0, record_BUTTON, green_LIGHT);
(0..63).do({|i| miniOut.noteOn(0, ((i/8).floor * 16) + (i%8), 0)});


noteOnFunc = {|vel, note, chan, port|
	["NOTE ON ENTERED", note].postln;
	if(note == record_BUTTON,{
		recording = recording.not;
		miniOut.noteOn(0, record_BUTTON, if(recording, red_LIGHT, green_LIGHT));
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
				if(savedScenes[note].isNil.not, {pythonOSCport.sendMsg("/playChord"++chordButtonChanMap[ind], ind);})
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