(var miniOut, mini, pythonOSCport, noteToInd, noteToXY, isPadNote, record_BUTTON, green_LIGHT, red_LIGHT, amber_LIGHT, savedScenes, recording, noteOnFunc, loadSavedSceneLights, indToNote, miniFwdOut, noteOffFunc, isSceneNote, ccFunc, scPort;



//TODO - add a "scene stack" in python in case you accidentally
//pull up an old scene before saving the one you're working on

//TODO - add a "load file" way to populate the correct lights

miniOut = MIDIOut.newByName("Launchpad Mini", "Launchpad Mini");
miniOut.latency = 0;
miniFwdOut = MIDIOut.newByName("IAC Driver", "Bus 5");
miniFwdOut.latency = 0;
pythonOSCport = NetAddr("localhost", 13371);
scPort = NetAddr("localhost", 57120);


mini = MIDIClient.sources.select({|elem| (elem.name == "Launchpad Mini")
	&& (elem.device == "Launchpad Mini")})[0];

//bottom left is 00
noteToInd = {|x|
	var row = 7 - (x / 16).asInt;
	var col = x % 16;
	var retVal = -1;
	if(col < 8, {retVal = row*10 + col});
	["note to ind", x, retVal].postln;
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
isSceneNote = {|x| isPadNote.(x) && (noteToInd.(x) >= 20)}; //bottom two rows are for samples
record_BUTTON = 8;
green_LIGHT = 48;
red_LIGHT = 3;
amber_LIGHT = 51;

savedScenes = Dictionary.new();
recording = false;

miniOut.noteOn(0, record_BUTTON, green_LIGHT);
(0..63).do({|i| miniOut.noteOn(0, ((i/8).floor * 16) + (i%8), 0)});


noteOnFunc = {|vel, note, chan, port|
	["NOTE ON ENTERED", note].postln;
	if(note == record_BUTTON,{
		recording = recording.not;
		miniOut.noteOn(0, record_BUTTON, if(recording, red_LIGHT, green_LIGHT));
	});
	if(isPadNote.(note),
		if(isSceneNote.(note), {
			if(recording, {
				pythonOSCport.sendMsg("/saveScene", noteToInd.(note));
                scPort.sendMsg("/saveMatrix", noteToInd.(note));
                miniOut.noteOn(0, note, amber_LIGHT);
                savedScenes[note] = true;
            },
            {
				if(savedScenes[note].isNil.not, {
                    pythonOSCport.sendMsg("/playScene", noteToInd.(note));
                    scPort.sendMsg("/playMatrix", noteToInd.(note));
                });
            })
        },
		{
			["SCENE NOTE", note].postln;
			miniFwdOut.noteOn(0, note, vel);
		})
	);
};
MIDIFunc.noteOn(noteOnFunc, nil, nil, mini.uid);

noteOffFunc = {|vel, note, chan, port|
	if(isSceneNote.(note).not, {miniFwdOut.noteOff(0, note, vel);});
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