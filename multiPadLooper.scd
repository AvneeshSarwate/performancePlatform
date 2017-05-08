//env vars for control
(
~truncateLoop = false;
)

(
var launchpadOut, padTL, padBL, padTR, padBR, colorBL1, colorBR1, colorTL1, colorTR1, colorBL2, colorBR2, colorTL2, colorTR2, colorON, pads, padMap, madePadList, scales, roots, padOn, padOff, setPadLights, transposes, makePadList, indToNote_, indToNote, midiOut, launchPad, tempoClock, interruptLoopButtons, controlChanInd, tapTempoSetButton, tapTempoToggle, recordButton, lastTap, playMetronome, recordingMetronome, metronomeFunc, preRecordCount, preRecordLength, recordBuffer, color1, tlBanks, trBanks, blBanks, brBanks, banks, bankMap, recordingState, bankSet, bankToSaveTo, bankToRecording, recordColor, tempLoopTask, tempLoopString, createRecordedTask, playingBanks, metronomeFlashTask, recordingInterim, resetRecordingState, interruptLooping, controlChanButton, arrowButtons, color2, up, down, left, right, padsByChannel, recordingStartBeat, recordingEndBeat, truncateLoop, quantize, algOrderList, pythonOSCport, algResponseHandler, algButtons, quantizationLevels, algBanks, liveCodeHandler, newKeyButton, masterClockOSCport, masterClockTempoHandler, onDeckBuffers, algChannelsInfo, recieveBuffer, startChannel, stringToBuf, stopChannel, rootScaleHandler, newKeysTransposes, newKeysPadIndToNote, newKeysSetPadLights, playingNewKeys, newKeysChan, hitListToNoteList, noteListToHitList, quantizeButton, quantizeColor, quantized, controlHandler, masterClockBeatHandler, setBankMelody, receiveScene, tempoalignTempoButton, alignTempo, buttonForwarding, buttonForwardingButton, metronomeOut, padIndToColor, moduleLights, controlHandlerWrapper, processPort;

//light switching variables
var setLight, ccLights, padColorState, cycleLight, lightIndex, cycleLight_BUTTON;

//MIDIClient.init;
//MIDIIn.connectAll;
launchpadOut = MIDIOut.newByName("Launchpad Pro", "Standalone Port");
launchpadOut.latency = 0;
midiOut = MIDIOut.newByName("IAC Driver", "Bus 2");
metronomeOut = MIDIOut.newByName("IAC Driver", "Bus 3");
midiOut.latency = 0;
metronomeOut.latency = 0;
pythonOSCport = NetAddr("localhost", 13371);
masterClockOSCport = NetAddr("localhost", 57120);
processPort = NetAddr("localhost", 12345);


//----------------------------------------------
//light switching variables
cycleLight_BUTTON = 95;
padColorState = Dictionary.new;
~padColors = padColorState;
ccLights = List.new;
(1..8).do({|i|
    ccLights.add(i);
    ccLights.add(90+i);
    ccLights.add(i*10);
    ccLights.add((i*10)+9);
});

setLight = {|note, color, lightIndexOverride=false|
    if((~lightIndex == lightIndex) || lightIndexOverride, {
        if(ccLights.includes(note),
            {launchpadOut.control(0, note, color)},
            {launchpadOut.noteOn(0, note, color)}
        );
    });
    padColorState[note] = color;
};
(1..98).do({|note|
    if(ccLights.includes(note),
        {launchpadOut.control(0, note, 0)},
        {launchpadOut.noteOn(0, note, 0)}
    );
    padColorState[note] = 0;
});
cycleLight = {
    //TODO: change name of this port to something like SCOSCport
    Task({
        masterClockOSCport.sendMsg("/lightsChange", (~lightIndex+1)%~lightIndexes.size);
        0.01.wait;
        ~lightIndex = (~lightIndex+1)%~lightIndexes.size;
    }).play;
};

//msg[1] is lightIndex
OSCFunc({|msg, time, addr, recvPort|
    if(msg[1].asInt == lightIndex, {
        var colorStateLog = List.new(100);
        (0..99).do({|i| colorStateLog.add(0)});
        padColorState.keys.do({|key| setLight.(key, padColorState[key], true);
            colorStateLog[key]=padColorState[key]});
        ["CHANGING MULTILOOP LIGHTS", msg[1], colorStateLog].postln;
    });

}, "/lightsChange");
lightIndex = if(~lightIndexes.size == 0,
    {
        ~lightIndexes.add(0);
        0
    },
    {
        ~lightIndexes.add(~lightIndexes.maxItem+1);
        ~lightIndexes.maxItem
    }
);
~lightIndex = lightIndex;
["LIGHT INDEX MULTILOOP", ~lightIndex, lightIndex].postln;
//TODO - add ~lightIndex == lightIndex condition to all launchpad note/cc hanlders
//----------------------------------------------





//OPTIONS
preRecordLength = 0;
~truncateLoop = true;
quantizationLevels = [3,4];




a = [1, 2, 3, 4];
b = [5, 6, 7, 8];

pads = Set.new();
padMap = Dictionary.new(); //launchpad-midiNote -> (padInd, channelInd)

makePadList = {|n1, n2, chan|
	var lis = List.new();
	k = 0;
	n1.do({|i| n2.do({|j|
		lis.add((i*10)+j);
		pads.add((i*10)+j);
		padMap.put((i*10)+j, [k, chan]);
		k = k+1;
	})});
	lis
};

algOrderList = List.new();

recordBuffer = List.new(200);

padTL = makePadList.(b, a, 0);
padTR = makePadList.(b, b, 1);
padBL = makePadList.(a, a, 2);
padBR = makePadList.(a, b, 3);
padsByChannel = [padTL, padTR, padBL, padBR];

(pads - padMap.keys()).postln;

colorTL1 = 39;
colorTR1 = 112;
colorBL1 = 4;
colorBR1 = 83;
color1 = [colorTL1, colorTR1, colorBL1, colorBR1];
l = color1;

colorTL2 = 25;
colorTR2 = 45;
colorBL2 = 72;
colorBR2 = 13;
color2 = [colorTL2, colorTR2, colorBL2, colorBR2];

padIndToColor = Dictionary.new();

colorON = 13;

tlBanks = [50, 60, 70, 80];
trBanks = [59, 69, 79, 89];
blBanks = [10, 20, 30, 40];
brBanks = [19, 29, 39, 49];
banks = [tlBanks, trBanks, blBanks, brBanks];
k = banks;
bankSet = Set.new();
bankSet.addAll(banks.flatten(1));
//midiNote -> [bankInd, bankChan, isOn, loopTask/nil, loopString, algMelodyTask, algMelodyString]
bankMap = Dictionary.new();
(0..3).do({|i| (0..3).do({|j|
	//setLight.(j, color1[i]);
	bankMap.put(banks[i][j], [j, i, false, nil, nil, nil, nil]); //TODO: reverse i,j here and everywhere else
})});
z = bankMap;
bankSet.do({|i| setLight.(i, 0)});
playingBanks = Set.new();
algBanks = List.new();

//chanInd -> [isOn, task, loopString]
(0..3).do({|i|
	algBanks.add([false, nil, nil]);
});


//define scales and roots
scales = [
	[0, 2, 3, 5, 7, 8, 10], //TL
	[0, 2, 3, 5, 7, 8, 10], //TR
	[0, 2, 3, 5, 7, 8, 10], //BL
	[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], //BR
];
roots = [60, 60, 48, 36];

indToNote_ = {|ind, scale, root, trans|
	root + scale[(ind+trans)%scale.size()] + (((ind+trans) / scale.size).floor * 12);
};

indToNote = {|ind, chan| indToNote_.(ind, scales[chan], roots[chan], transposes[chan])};

transposes = [-1, 4, -12, 0 ]; //+- 4 corresponds to up/down a row, +-1 corresponds to left/right a column

quantizeButton = 97;
quantizeColor = 8;
quantized = false;

buttonForwardingButton = 96;
buttonForwarding = false;

//---------------------------------------------------------------------------------------------
//---------------------------------------------------------------------------------------------
//newKeyboard stuff
newKeysTransposes = [-12, -12, -12, -12];  //+- 5 for vertical, +- 1 for horizontal

newKeyButton = 98;

playingNewKeys = false;

newKeysChan = 0;
//TODO - rename ctrlChanInd variable - it is actually newKeysChan
newKeysPadIndToNote = {|padInd, ctrlChanInd|
	var ind = padInd - 11;
	var noteInd, note;
	if(padInd >  18,
		{noteInd = (ind-(((ind/10).floor)*5))},
		{noteInd = ind}
	);
	note = roots[ctrlChanInd] + noteInd + newKeysTransposes[ctrlChanInd];
	//["NOTE-IND", ind,noteInd, note].postln;
	note;
};

newKeysSetPadLights = {|ctrlChanInd|
	var root = roots[ctrlChanInd];
	var scale = scales[ctrlChanInd];
	(1..8).do({|i|
		(1..8).do({|j|
			var ind = i*10 + j;
			var note = newKeysPadIndToNote.(ind, ctrlChanInd);
			var isRoot = (note%12) == (root%12);
			var floorRoot = note - (((note%12) - (root%12)) % 12);
			var isInScale = scale.collect({|n| floorRoot + n}).includes(note);
            var moduleLight;
			["LIGHT", note, isInScale, isRoot, scale.collect({|n| floorRoot + n}).includes(note), scale.collect({|n| floorRoot + n})].postln;
			if(isInScale && isRoot.not, {
				setLight.(ind, color1[ctrlChanInd]);
				padIndToColor[ind] = color1[ctrlChanInd];
			});
			if(isRoot, {
				setLight.(ind, color2[ctrlChanInd]);
				padIndToColor[ind] = color2[ctrlChanInd];
			});
			if(isInScale.not, {
				setLight.(ind, 0);
				padIndToColor[ind] = 0;
			});
            moduleLight = ~moduleLightsPerChannel[ctrlChanInd][ind];
            if(moduleLight.isNil.not, {setLight.(ind, moduleLight)});
		});
	});
};
//---------------------------------------------------------------------------------------------
//---------------------------------------------------------------------------------------------

//(note%12 - root%12)%12

//TODO: this feature isn't triggerable
tempoalignTempoButton = 100;
alignTempo = false;

arrowButtons = [91, 92, 93, 94];
up = 91;
down = 92;
right = 93;
left = 94;

interruptLoopButtons = [1, 2, 3, 4];
interruptLooping = [false, false, false, false, false];
setLight.(1, colorTL1);
setLight.(2, colorTR1);
setLight.(3, colorBL1);
setLight.(4, colorBR1);

controlChanInd = 0;
controlChanButton = 8;
setLight.(controlChanButton, color1[controlChanInd]);

onDeckBuffers = List.fill(16, {nil;});

//[task, midiChanInd]
algChannelsInfo = List.fill(16, {[nil, nil];});


//define setPadLights method
setPadLights = {|padMIDIs, c1, c2, padInd|
	(0..15).do({|i|
		var col;
		if(((i+transposes[padInd]) % scales[padInd].size) == 0, {col = c2}, {col = c1});
		setLight.(padMIDIs[i], col);
		padIndToColor[padMIDIs[i]] = col;
	});
};

setPadLights.(padTL, colorTL1, colorTL2, 0);
setPadLights.(padTR, colorTR1, colorTR2, 1);
setPadLights.(padBL, colorBL1, colorBL2, 2);
setPadLights.(padBR, colorBR1, colorBR2, 3);

launchPad = MIDIClient.sources.select({|elem| (elem.name == "Standalone Port")
	&& (elem.device == "Launchpad Pro")})[0];
[launchPad, MIDIClient.sources[2]].postln;
a = {|vel, note, chan, port|
    if((chan == 0) && (~lightIndex == lightIndex), {
        ["LIGHT INDEX MULTILOOP", ~lightIndex, lightIndex].postln;
		if(pads.includes(note), {
			var chan, newNote;
			if(playingNewKeys,
				{
					newNote = newKeysPadIndToNote.(note, newKeysChan);
					chan = newKeysChan;
				},
				{
					var padInfo = padMap[note];
					newNote = indToNote.(padInfo[0], padInfo[1]);
					chan = padInfo[1];
				}
			);
			if(buttonForwarding && (controlChanInd == chan),
				{pythonOSCport.sendMsg("/buttonForwarding", chan, newNote, vel, "on", note)},
				{midiOut.noteOn(chan, newNote, vel)}
			);
			if(recordingMetronome, {recordBuffer.add([tempoClock.beats, newNote, vel, chan, "on"])});
		});
	});
};
padOn = MIDIFunc.noteOn(a, nil, nil, launchPad.uid);

b = {|vel, note, chan, port|
	if((chan == 0) && (~lightIndex == lightIndex), {
        ["LIGHT INDEX MULTILOOP", ~lightIndex, lightIndex].postln;
		if(pads.includes(note), {
			var chan, newNote;
			if(playingNewKeys,
				{
					newNote = newKeysPadIndToNote.(note, newKeysChan);
					chan = newKeysChan;
				},
				{
					var padInfo = padMap[note];
					newNote = indToNote.(padInfo[0], padInfo[1]);
					chan = padInfo[1];
				}
			);

			if(buttonForwarding && (controlChanInd == chan),
				{pythonOSCport.sendMsg("/buttonForwarding", chan, newNote, vel, "off", note)},
				{midiOut.noteOff(chan, newNote, vel)}
			);
			if(recordingMetronome, {recordBuffer.add([tempoClock.beats, newNote, vel, chan, "off"])});
		});
	});
};
padOff = MIDIFunc.noteOff(b, nil, nil, launchPad.uid);
x = 0;
tempLoopTask = nil; //this var is only not nil when you have a recorded and unsaved loop
tempLoopString = nil;


//does NOT include timeAfterLastHit
//makes assumption that there is always a noteOn before a noteOff
hitListToNoteList = {|hitList|
	var notesToStartStop = Dictionary.new();
	var noteList = List.new();
	var timeSoFar = 0;
	var count = 1;
	"AAAAAAA".postln;
	x = hitList;
	"A1".postln;
	hitList.do({|hit|
		//hit.postln;
		timeSoFar = timeSoFar + hit[0];
		if(notesToStartStop[hit[1]].isNil,
			//time, velocity, midiChan, on/off
			{notesToStartStop[hit[1]] = [[timeSoFar,  hit[2], hit[3], hit[4]]].asList},
			{
				count = count+1;
				//["pre", notesToStartStop[hit[1]].size].postln;
				notesToStartStop[hit[1]].add([timeSoFar,  hit[2], hit[3], hit[4]]);
				//["post", notesToStartStop[hit[1]].size].postln;
			}
	)});
	"A2".postln;
	//notesToStartStop.postln;
	notesToStartStop.keys.do({|midiNote|
		var startStop = notesToStartStop[midiNote];
		[count, startStop.size].postln;
		(0,2..(startStop.size-2)).do({|ind|
			//time, midiNote, onVelocity, midiChan, duration
			noteList.add([startStop[ind][0], midiNote, startStop[ind][1], startStop[ind][2], startStop[ind+1][0]-startStop[ind][0]]);
		});
	});

	noteList.sort({|a, b| a[0] < b[0]});
	"A3".postln;
	noteList;
};
y = hitListToNoteList;

noteListToHitList = {|noteList|
	var intermediateHitList = List.new();

	noteList.do({|n|
		intermediateHitList.add([n[0], n[1], n[2], n[3], "on"]);
		intermediateHitList.add([n[0]+n[4], n[1], 0, n[3], "off"])
	});
	["B1", noteList.size, intermediateHitList.size].postln;
	intermediateHitList.sort({|a, b| a[0] < b[0]});

	"B2".postln;
	((intermediateHitList.size-1), (intermediateHitList.size-2)..1).do({|ind|
		intermediateHitList[ind][0] = intermediateHitList[ind][0] - intermediateHitList[ind-1][0];
	});

	intermediateHitList
};

z = noteListToHitList;

//TODO: alternative - quantaize to 4ths or 6ths, chose based on minimum error (can change per beat)
//{hit[0] = hit[0].floor + ((hit[0]%1 * 6).round / 6)}
//NOTE - translates hitTime -> duration-before-hit for each beat
quantize = {|oldRecBuf, quantDivArray, startBeat, endBeat|

	//divide array into hits-per-beat
	//apply calc-error-for-hits-and-div
	//select div with least error
	var currentBeat = 0;
	var notesPerBeat = List.new();
	var quantizedNotes = List.new();
	var hangingNotes = Set.new();
	var recBuf = List.newFrom(oldRecBuf);
	var newBuf;
	var timeAfterLastHit;
	var populatedBeatsCount = -1;
	var melodyEndingBeat;


	recBuf.do({|hit| if(hit[0] < startBeat, {hit[0] = startBeat}) });
	recBuf.do({|elem|
		if(elem[4] == "on",
			{hangingNotes.add([elem[1], elem[3]])},
			{hangingNotes.remove([elem[1], elem[3]])})
	});
	hangingNotes.do({|elem| recBuf.add([endBeat-0.01, elem[0], 0, elem[1], "off"])});

	melodyEndingBeat = recBuf[recBuf.size-1][0].ceil;

	if(~truncateLoop,
		{timeAfterLastHit = (recBuf[recBuf.size-1][0].ceil - recBuf[recBuf.size-1][0])},
		{timeAfterLastHit = endBeat - recBuf[recBuf.size-1][0]}
	);

	(recBuf.size-1..1).do({|i| recBuf[i][0] = recBuf[i][0] - recBuf[i-1][0]});
	recBuf[0][0] = recBuf[0][0] - startBeat;

	"PRE NOTES".postln;
	newBuf = hitListToNoteList.(recBuf, startBeat);
	//newBuf.do({|note| note.postln});
	"B".postln;
	newBuf = noteListToHitList.(newBuf);
	if(recBuf == newBuf, {"MATCH".postln}, {
		"NO MATCH".postln;
		(0..recBuf.size).do({|ind|
			[ind+":  ", recBuf[ind], "      ", newBuf[ind]].postln
		});
	});
	"POST NOTES".postln;

	//todo - quantize based on "notes" instead of hits - shift noteOn but keep note duration the same
	newBuf = hitListToNoteList.(recBuf, startBeat);
	["noteList", newBuf.size].postln;
	//todo - quant start - can drop in noteList here instead of hit list?
	newBuf.do({|hit|
		var indexBeat = hit[0].floor;
		//["HIT", indexBeat, currentBeat, hit].postln;
		if(indexBeat >= currentBeat, {
			notesPerBeat.add(List.new());
			currentBeat = indexBeat;
			populatedBeatsCount = populatedBeatsCount + 1;
		});
		notesPerBeat[populatedBeatsCount].add(hit);
	});
	["notes per beat", notesPerBeat.collect({|a| a.size})].postln;
	notesPerBeat.do({|hits|
		var quantLists = List.new();
		var bestList = [List.new(), 1];
		var quantHitList;
		quantDivArray.do({|div|
			var quantList = List.new();
			var error = 0; //ignore noteOff messages for error calculation
			hits.do({|hit| quantList.add(hit[0].floor + ((hit[0]%1 * div).round / div))});
			(0..(hits.size-1)).do({|i| error = error + (hits[i][0] - quantList[i]).abs; "error".postln;});
			[(hits.size-1), hits[0][0].floor, error, div, error/div, hits.collect({|hit| hit[0]})].postln;
			quantLists.add([quantList, error]);
		});
		"-----".postln;
		quantLists.do({|listErr| if(listErr[1] < bestList[1], {bestList = listErr})});
		quantHitList = List.fill(hits.size, {|i|
			var newHit = List.newFrom(hits[i]);
			newHit[0] = bestList[0][i];
			newHit
		});
		quantizedNotes.add(quantHitList);
	});
	["num quantized notes pre", quantizedNotes].postln;
	quantizedNotes = quantizedNotes.inject(List.new(), _++_);
	["num quantized notes post", quantizedNotes].postln;
	//quantizedNotes.do({|note| note.postln});
	//todo - quant end

	//TODO - something still messed up with long held notes
	//TOGGLE QUANTIZATION HERE
	if(quantized, {
		var loopDur = if(~truncateLoop,  melodyEndingBeat - startBeat, endBeat - startBeat);
		var maxEnd = 0;

		["timeAFterLastHit", startBeat, endBeat, melodyEndingBeat].postln;

		//modify noteEnds and timeAfterLastBeat s.t. it is still within an integral beat length
		quantizedNotes.do({|note|
			if((note[0] + note[4]) > loopDur, {note[4] = loopDur - 0.001});
			if((note[0] + note[4]) > maxEnd, {maxEnd = note[0] + note[4]});
		});

		//recalculate timeAfterLastHit
		timeAfterLastHit = loopDur - maxEnd;

		recBuf = noteListToHitList.(quantizedNotes);


	});

	timeAfterLastHit.postln;

	//recBuf.do({|hit| if(true/*hit[4] == "on", {["HIT TIME", hit[4], hit[0]].postln})});


	recBuf.add([timeAfterLastHit, 0, 0, 0, "timeAfterLastHit"]); //xtra vals to simlpify save/load serialization

	"EXIT QUANTIZE".postln;
	recBuf;
	//recBuf.do({|hit| ["Duration TIll", hit[4], hit[0]].postln});
	//["time after last", timeAfterLastHit].postln;
};


createRecordedTask = {|oldRecBuf, isChannelTask=false, channelInd=0|
	var startBeat, timeAfterLastHit, recBuf, newTask, chan;

	recBuf = List.newFrom(oldRecBuf);
	chan = recBuf[0][3];

	//todo - this could phase a tiiiiny bit if left running for ages
	newTask = Task({
		var ind = 0;
		var hit;
		var endWait = 0;
		{
			hit = recBuf[ind];
			hit[0].wait;
			if(interruptLooping[chan].not, {
				if(hit[4] == "on", {midiOut.noteOn(hit[3], hit[1], hit[2]);});
				if(hit[4] == "off", {midiOut.noteOff(hit[3], hit[1], hit[2])});
			});
			ind = ind+1; //TODO - should this be after the switch to the ondeck buffer?

			if(isChannelTask, {
				if(ind == (recBuf.size-2), {
					pythonOSCport.sendMsg("/algRequestUpdate", channelInd);
				});

				if(ind == (recBuf.size), {
					//["SHOULD BE timeAfterLastHit", ind, hit[4]].postln;
					if(onDeckBuffers[channelInd] != nil, {
						recBuf = onDeckBuffers[channelInd];
						ind = 0;
						onDeckBuffers[channelInd] = nil;
					});
				});
			});

			ind = ind%recBuf.size;
		}.loop;
	}, tempoClock);

	newTask;
};
r = createRecordedTask;



//TODO: move variable instations to near the functions that use them
OSCFunc({|msg, time, addr, recvPort|
	//msg[1] is the new BEAT DURATION (not tempo)
	tempoClock = TempoClock.new(1/msg[1], 0);
	t = tempoClock;
	tempoClock.schedAbs(1, metronomeFunc);
	"MULTILOOP ONE SHOT".postln;
}, "/masterClockBeat").oneShot;
masterClockBeatHandler = {|msg, time, addr, recvPort|
	//["MULTILOOP BEAT", tempoClock.beats].postln;
};
OSCFunc(masterClockBeatHandler, "/masterClockBeat");
tapTempoSetButton = 5;
tapTempoToggle = 6;
recordButton = 7;
recordColor = 5;
setLight.(recordButton, recordColor);
setLight.(quantizeButton, 0);
lastTap = TempoClock.beats;
playMetronome = false;
recordingMetronome = false;
recordingInterim = false;
preRecordCount = 0;
//0: not recording, 1: pre record metronome, 2: recording notes 3:stopped recording and tempBuffer full
recordingState = 0;
bankToSaveTo = 0;
bankToRecording = Dictionary.new();
controlHandler = {|vel, note, chan, port|
	if(interruptLoopButtons.includes(note), {
		var chan = note - interruptLoopButtons[0];
		if((vel == 127), {midiOut.allNotesOff(chan)});
		interruptLooping[chan] = vel == 127;
	});
	if((note == tapTempoSetButton) && (vel == 127), {
		var now = TempoClock.beats;
		if((now - lastTap) < 2, {masterClockOSCport.sendMsg("/uploadTempo", now - lastTap, alignTempo)});
		lastTap = now;
	});
	if((note == tempoalignTempoButton) && (vel == 127), {
		alignTempo = alignTempo.not;
		if(alignTempo,
			{setLight.(tempoalignTempoButton, 81)},
			{setLight.(tempoalignTempoButton, 0)}
		);
	});
	if((note == buttonForwardingButton) && (vel == 127), {
		buttonForwarding = buttonForwarding.not;
		if(buttonForwarding,
			{setLight.(buttonForwardingButton, 81)},
			{setLight.(buttonForwardingButton, 0)}
		);
        ["MULTI LOOP 96", ~lightIndex].postln;
	});
	if((note == tapTempoToggle) && (vel == 127), {playMetronome = playMetronome.not});
	if((note == recordButton) && (vel == 127), {
		//TODO = case statement
		if(recordingState == 0, { //start recording
			bankToSaveTo = 0;
			recordingState = 1;
			recordingMetronome = true;
			preRecordCount = 0;
		});
		if(recordingState == 3, { //discarding loop
			tempLoopTask.stop;
			recordBuffer.do({|elem| midiOut.noteOff(elem[3], elem[1])});
			tempLoopTask.free;

			resetRecordingState.();
		});
		if(recordingState == 2, { //stop recording
			var recBuf;
			recordingState = 3;
			preRecordCount = 0;
			recordingMetronome = false;
			recordingEndBeat = tempoClock.beats.round;

			//TODO: handle cases where multiple inst hits in a recBuf, or when there's no noteOns recorded
			chan = recordBuffer[0][3];

			recBuf = quantize.(recordBuffer, quantizationLevels, recordingStartBeat, recordingEndBeat);

			tempLoopString = recBuf.collect({|item| item.join(",")}).join("-");
			tempLoopTask = createRecordedTask.(recBuf);
			tempoClock.sched(tempoClock.timeToNextBeat, {tempLoopTask.start; nil;});
		});
	});
	if(bankSet.includes(note) && (vel == 127), {
		var thisBank = bankMap[note];
		if(recordingState == 3,
			{
				//save the recorded buffer to the appropriate bank
				if(thisBank[3] != nil, {
					thisBank[3].stop;
					thisBank[3].free;
				});
				thisBank[2] = true;
				thisBank[3] = tempLoopTask;
				thisBank[4] = note + tempLoopString + recordingStartBeat;

				pythonOSCport.sendMsg("/saveLoop",  thisBank[1], thisBank[0],
					roots[thisBank[1]], scales[thisBank[1]].join(","), thisBank[4]);

				playingBanks.add(note);
				resetRecordingState.();
			},
			{
				if(thisBank[3] != nil, {
					//if algsList.size > 0, make OSC call to python alg module
					//args - algsList, inst chanel, bank numner, loopString
					//set recivedAlgTask[chanInd][bankNum] = null
					//if the python func crashes, this remains null and can be checked for
					if(algOrderList.size > 0, {
						pythonOSCport.sendMsg("/algRequest",  thisBank[1], thisBank[0],
							roots[thisBank[1]], scales[thisBank[1]].join(","), thisBank[4])
					});

					tempoClock.sched(tempoClock.timeToNextBeat, {
						if(thisBank[2].not,
							{
								if(false, {//with this as false, banks can be overlayed
									//for all other banks for this inst, stop playing and turn their lights on
									banks[thisBank[1]].do({|bNote|
										if(bankMap[bNote][3] != nil, {
											var elem = bankMap[bNote];
											elem[3].stop;
											elem[2] = false; //TODO: refactor to make bank on/off functions
											Task({0.001.wait; setLight.(bNote, color1[elem[1]]);}).play;
											playingBanks.remove(bNote);
									})
								});});
								//TODO: this won't kill notes of an instrument thats not on this channel
								//TODO: with newKeys, should generalize coloring of loop banks
								//midiOut.allNotesOff(thisBank[1]);
								if(thisBank[5].isNil, {thisBank[3].start}, {thisBank[5].start});
								thisBank[2] = true;
								playingBanks.add(note);
								pythonOSCport.sendMsg("/loopPlay", thisBank[1], thisBank[0], true); //mark python loop-info as playing
							},
							{
								midiOut.allNotesOff(thisBank[1]);
								"TURNING OFF".postln;
								thisBank[3].stop;
								thisBank[5].stop;
								thisBank[5].free;
								thisBank[5] = nil;
								thisBank[6] = nil;
								thisBank[2] = false;
								setLight.(note, color1[thisBank[1]]);
								playingBanks.remove(note);
								pythonOSCport.sendMsg("/loopPlay", thisBank[1], thisBank[0], false); //mark python loop-info as stopped
						});
						"TEMPOCLOCK FUNC RUN".postln;
						//setLight.(note, 0);
						nil;
					});
				});
		});
	});
	if((note == controlChanButton) && (vel == 127), {
		controlChanInd = (controlChanInd+1) % 4;
		setLight.(controlChanButton, color1[controlChanInd]);
		newKeysChan = controlChanInd;
		if(playingNewKeys, {newKeysSetPadLights.(controlChanInd)});
		//todo - turn off note if swapping between different channels on newKeys or to/from newKeys to old
	});
	if((note == newKeyButton) && (vel == 127), {
		//Todo newKeys - activate lighting wrt to the chan specified by controlChanButton
		if(playingNewKeys,
			{
				playingNewKeys = false;
				(0..3).do({|i|
					setPadLights.(padsByChannel[i], color1[i], color2[i], i);
				});
			},
			{
				playingNewKeys = true;
				newKeysChan = controlChanInd;
				newKeysSetPadLights.(controlChanInd);
			}
		);
	});
	if((note == quantizeButton) && (vel == 127), {
		quantized = quantized.not;
		if(quantized,
			{setLight.(quantizeButton, quantizeColor)},
			{setLight.(quantizeButton, 0)}
		);
	});
	if(arrowButtons.includes(note) && (vel == 127), {
		//todo: note off all for that instrument
		//Todo newKeys - lighting shift
		if(playingNewKeys,
			{
				var ind = newKeysChan;
				if(note == up, {newKeysTransposes[ind] = newKeysTransposes[ind] - 5});
				if(note == down, {newKeysTransposes[ind] = newKeysTransposes[ind] + 5});
				if(note == right, {newKeysTransposes[ind] = newKeysTransposes[ind] + 1});
				if(note == left, {newKeysTransposes[ind] = newKeysTransposes[ind] - 1});
				newKeysSetPadLights.(ind);
			},
			{
				var ind = controlChanInd;
				if(note == up, {transposes[ind] = transposes[ind] - 4});
				if(note == down, {transposes[ind] = transposes[ind] + 4});
				if(note == right, {transposes[ind] = transposes[ind] + 1});
				if(note == left, {transposes[ind] = transposes[ind] - 1});
				setPadLights.(padsByChannel[ind], color1[ind], color2[ind], ind);
			}
		);
	});
	//MULTIPLE ALG BUTTONS CAN BE HELD DOWN
	//THEIR ORDER WILL SPECIFY A "pipeline" of transformations
	//if alg button, add/remove from list depending on button up/down
	if((note == cycleLight_BUTTON) && (vel !=0), {
        // ["MULTILOOP BUTTON CYCLE HIT", ~lightIndex, lightIndex].postln;
        if(~cycling, {cycleLight.()})
    });
};
controlHandlerWrapper = {|vel, note, chan, port|
    ~lock.wait;
    if((chan == 0) && (~lightIndex == lightIndex) && (vel != 0), {
        ["LIGHT INDEX MULTILOOP", ~lightIndex, lightIndex, SystemClock.beats].postln;
        controlHandler.(vel, note, chan, port)
    });
    ~lock.signal;
};
MIDIFunc.cc(controlHandlerWrapper, nil, nil, launchPad.uid);

//midiNote -> [bankInd, bankChan, isOn, loopTask/nil, loopString, algMelodyTask, algMelodyString]
setBankMelody = {|button, hitString, startBeat, playing|
	var hitList, startFunc;

	//todo - enable this to minimize latency?
	//melodyTask = createRecordedTask.(stringToBuf.(hitString));
	["CREATED TASK", button].postln;

	startFunc = {
		var bank = bankMap[button];
		bank[3] = createRecordedTask.(stringToBuf.(hitString));
		bank[4] = hitString;
		setLight.(button, color1[bank[1]]);
		nil;
		["START FUNC NOW"].postln;
		if(playing, {
			bank[3].play;
			bank[2] = true;
		});
	};
	if(playing, {playingBanks.add(button)});
	tempoClock.sched(tempoClock.timeToNextBeat, startFunc);
};

//msg = [/address, melody/info-strList, roots, scales]
receiveScene = {|msg, time, addr, recvPort|
	//set roots and scales
	var count = 0;

	roots = msg[2].asString.split($,).collect({|str| str.asInt});
	scales = msg[3].asString.split($,).collect({|str| str.split($.).collect({|st| st.asInt})});

	//set pad lights

	if(playingNewKeys,
		{newKeysSetPadLights.(newKeysChan)},
		{(0..3).do({|ind|setPadLights.(padsByChannel[ind], color1[ind], color2[ind], ind)})}
	);

	playingBanks = List.new();
	bankMap.keys.do({|button|
		var bank = bankMap[button];
		var stopFunc = {
			//["STOP FUNC NOW", bank[3].isNil].postln;
			if(bank[3].isNil.not, {
				bank[3].stop;
				bank[3].free;
				bank[3] = nil;
				bank[4] = nil;
				bank[2] = false;
				setLight.(button, 0);
				midiOut.allNotesOff(bank[1]);
			});
			nil;
		};
		tempoClock.sched(tempoClock.timeToNextBeat-0.01, stopFunc);
	});

	//split string and set banks
	msg[1].asString.split($:).do({|bankStr|
		if(bankStr != "none",
			{
				var split, bankInfo;
				split = bankStr.split($ );
				["bankCount", count, split[0]].postln;
				count = count+1;
				bankInfo = [split[0].asInt, split[1], split[2].asFloat, (split[3].asInt == 1)];
				["setBankMelodyArgs", bankInfo[0], bankInfo[2], bankInfo[3], bankInfo[1]].postln;
				setBankMelody.(bankInfo[0], bankInfo[1], bankInfo[2], bankInfo[3]);
			}
		);
	});
};
OSCFunc(receiveScene, "/sendScene");



//msg[1] is channel
//msg[2] is bufferString
recieveBuffer = {|msg, time, addr, recvPort|
	var buffer = stringToBuf.(msg[2].asString.split($ )[1]); //todo - remove the string filler that caused the bug here
	["UPDATE", msg].postln;
	onDeckBuffers[msg[1].asInt] = buffer;
};
OSCFunc(recieveBuffer, "/algRecieveUpdate");

//msg[1] is channel
//msg[2] is bufferString
startChannel = {|msg, time, addr, recvPort|
	var buffer, chanInd, channelTask;
	["START CHAN", msg].postln;
	buffer = stringToBuf.(msg[2].asString.split($ )[1]);
	"BUFFER READ".postln;
	chanInd = msg[1].asInt;
	channelTask = createRecordedTask.(buffer, true, chanInd);
	"ALG TASK CREATED".postln;
	if(algChannelsInfo[chanInd][0].isNil.not, {
		algChannelsInfo[chanInd][0].stop;
		algChannelsInfo[chanInd][0].free;
		algChannelsInfo[chanInd][0] = nil;
		midiOut.allNotesOff(algChannelsInfo[chanInd][1]);
		//TODO: figure out how to time the "stop" of previous task on channel properly
		/*var taskInfo = algChannelsInfo[chanInd];
		tempoClock.sched(tempoClock.timeToNextBeat - 0.05, {
			taskInfo[0].stop;
			taskInfo[0].free;
			midiOut.allNotesOff(taskInfo[1]);
			["STOP DOUBLE ALG ON CHAN", chanInd].postln;
		});*/
	});
	algChannelsInfo[chanInd][0] = channelTask;
	algChannelsInfo[chanInd][1] = buffer[0][3];
	tempoClock.sched(tempoClock.timeToNextBeat, {channelTask.play; nil;});
	"START CHANNEL DONE".postln;
};
OSCFunc(startChannel, "/algStart");

//msg[1] is channel
stopChannel = {|msg, time, addr, recvPort|
	var chanInd;
	["STOP CHAN", msg].postln;
	chanInd = msg[1].asInt;
	tempoClock.sched(tempoClock.timeToNextBeat - 0.05, {
		"ACTUALLY STOPPING CHAN".postln;
		if(algChannelsInfo[chanInd][0].isNil.not, {
			algChannelsInfo[chanInd][0].stop;
			algChannelsInfo[chanInd][0].free;
			algChannelsInfo[chanInd][0] = nil;
		});
		["PROBLEM", algChannelsInfo[chanInd][1]+0].postln;
		midiOut.allNotesOff(algChannelsInfo[chanInd][1]);
		nil;
	});
};
OSCFunc(stopChannel, "/algStop");

stringToBuf = {|melString|
	var buf = melString.split($-).collect({|hitString|
		var sp = hitString.split($,);
		[sp[0].asFloat, sp[1].asInt, sp[2].asInt, sp[3].asInt, sp[4]]
	});
	//buf.do({|b| b.postln;});
	buf
};

//msg[1] is the new BEAT DURATION (not tempo)
//msg[2] is whether the beat is being realigned
masterClockTempoHandler = {|msg, time, addr, recvPort|
	tempoClock.tempo = 1/msg[1].asFloat;
	if(msg[2].asBoolean, {tempoClock.beats = tempoClock.beats.floor + 1});
};
OSCFunc(masterClockTempoHandler, "/masterClockTempo");


///msg[1, 2, 3] is [root:int, scale:, joined Str of Ints, chan:int]
rootScaleHandler = {|msg, time, addr, recvPort|
	msg[2].postln;
	roots[msg[3].asInt] = msg[1].asInt;
	scales[msg[3].asInt] = msg[2].asString.split($,).collect({|str| str.asInt});
	//TODO - add changing pad coloring upon reciept of scale
	if(playingNewKeys,
		{newKeysSetPadLights.(controlChanInd)},
		{(0..3).do({|i| setPadLights.(padsByChannel[i], color1[i], color2[i], i)})}
	);
	["root-Scale Change", msg[1].asInt, scales[msg[3].asInt]].postln;
};
OSCFunc(rootScaleHandler, "/rootScale");

/*
python module

class AlgResponder:
- algsList[] - a list of algs that takes a loopString and returns a loopString (default is identity function)
  the elements of this list are what will be replaced with custom functions when live coding
- an oscHandler that applies algslist in order specified by oscAlgsList argument and
  returns the final loop string (along with chanInd and bankNum)


*/
resetRecordingState = {
	recordingMetronome = false;
	recordingState = 0;
	setLight.(recordButton, recordColor);
	recordBuffer.clear();
	tempLoopTask = nil;
	tempLoopString = nil;
};

metronomeFlashTask = Task({
	if(recordingMetronome || (tempLoopTask != nil),
		{setLight.(recordButton, (recordingState==2).if(17,recordColor))});
	playingBanks.do({|bNote| setLight.(bNote, color1[bankMap[bNote][1]])});
	(tempoClock.beatDur/2).wait;
	if(recordingMetronome || (tempLoopTask != nil), {setLight.(recordButton, 0)});
	playingBanks.do({|bNote| setLight.(bNote, 0)});
});

metronomeFunc = {
	//"PAD METRONOME FUNC".postln;
	metronomeFlashTask.start;
	if(recordingMetronome, {
		if((preRecordCount < preRecordLength),
			{
				recordingInterim = true;
				preRecordCount = preRecordCount + 1;
				["prerecordMetronome", preRecordCount].postln;
			},
			{//TODO: clean up and write comments for recroding state handling
				if(recordingState == 1, {
					recordingState = 2;
					recordingStartBeat = tempoClock.beats.round;
				});
				recordingInterim = false;
				"RECORDING".postln;
			}

		);
	});
	if(playMetronome, {
		if(recordingMetronome,
			{
				Task({ //TODO - refactor duration note on/off stuff into functions
					var drum = recordingInterim.if(37, 38);
					metronomeOut.noteOn(4, drum, 64); 0.05.wait; midiOut.noteOff(4, drum, 64);}).play;
			},
			{
				Task({metronomeOut.noteOn(4, 36, 64); 0.05.wait; midiOut.noteOff(4, 36, 64); }).play;
		});
	});
	//["beat", tempoClock.beats, tempoClock.beatDur].postln;
	1;
};


/*
general idea - multiPadLooper can expose info about basic pad color state (eg, padToColorMap and
padToNote/ChanMap),but module is responsible for managing its own color state. pad could push events
(eg, keyboard scrolling, switching btw quad/extended keyboards, switching inst on extended)
to let module recolor as necessary. Upon event occuring, keyboard will recolor first
(thus updating padToColorMap), and then module will update lights afterwards.
TODO - add event broadcasting for multiPadLooper color state change.
*/
// msg [addr, padInd, color(-1 if revert to old), repeated]
~basePadColors = padIndToColor;

//best practice is to only have 1 hyperkeyboard that changes pad-lighting at a time
//nil value means no special module lighting for that key
~moduleLightsPerChannel = Dictionary.new;
(0..3).do({|i|
    ~moduleLightsPerChannel[i] = Dictionary.new;
});
//msg = [addr, key, color, chanInd]
moduleLights = {|msg, time, addr, recvPort|
	["MODULE LIGHTS", msg].postln;
	(1,3..(msg.size-2)).do({|i|
		if(msg[i+1] > 0,
			{
                if(playingNewKeys && (controlChanInd == msg[3].asInt), {setLight.(msg[i], msg[i+1])});
                ~moduleLightsPerChannel[msg[3].asInt][msg[i]] = msg[i+1];
            },
			{
                if(playingNewKeys && (controlChanInd == msg[3].asInt), {setLight.(msg[i], padIndToColor[msg[i]])});
                ~moduleLightsPerChannel[msg[3].asInt][msg[i]] = nil;
            }
		);
	})
};
OSCFunc(moduleLights, "/moduleLights");

OSCFunc({|msg, time, addr, recvPort|
    Task({
        var colorList = List.new;
        var selectedList = List.new;
        0.1.wait;
        (8..1).do({|i|
            (1..8).do({|j|
                var colStr = switch(~basePadColors[i*10+j], 112, {"key"}, 45, {"root"}, 21, {"on"}, 0, {"nk"});
                var selStr = if(~padColors[i*10+j] == 21, {"sel"}, {"nsel"});
                colorList.add(colStr);
                selectedList.add(selStr);
            });
        });
        processPort.sendMsg("/processMatrices", msg[1] , colorList.join("."), selectedList.join("."));
    }).play
},"/chordPadIndFwd")


/*
basic layout
   - 4 keyboards, 1 in each quadrant, with 4 melody banks each (color coded on side - buttons)
     where the bank button of a playing bank will be flashing
   - keyboards will have "highlighted" scale roots, and you can "shift" the keyboard up/down/left right
     just like in the quneoSoloKeyboard by using the arrow keys
   - there will be a metronome for keeping the "pulse", and all recorded loops will be an integral
     number of pulses in duration
   - 3 main control buttons (top row) - tap tempo (flashes with metronome), metronome audio on/off,
     recording start/stop, (optionally) "visual play" on/off. "visual play" means that when a clip plays,
     the keyboard layout for that instrument will revert to what it was when the clip was recorded, and
     the "keys" will light up as the note sounds (might not be doable if keyboard is shifted while recording)
   - how to do "interrupt looping"? separate interupt-button for each instrument, held down to "interupt",
     or simply hold down flashing/playing clip to interupt it?
   - what if you want to replay a clip from the start when its already playing
   - saved clip will be launched at start of next complete "pulse", with minor "lateness" in pad hit forgiven
*/

)

// ================================================================================================
// ================================================================================================
//FILE SAVE/LOAD


(
var func = {|a, b=5|
	[a, b].postln;
};
func.(1)
)
(
a = [1, 4, 5];
a.wrapAt(-1)
)
(
var file = File("~/joelLoop.txt".standardizePath, "wb");
var lines = List.new();
f.keys.do({|key|
	if(f[key][4] != nil, {
		var str = f[key][4]++"\n";
		lines.add(f[key][4]);
		str.postln;
		//file.putString(str);
	});
});
file.putString(lines.join("\n"));
file.close;
5
)
"5,6,5,3,2,8,5,4,3".split($,)
[ 5, 6, 5, 3, 2, 8, 5, 4, 3 ].join(",")
(
var file = File.open("~/testFilename4.txt".standardizePath, "rb");
var fileStr = file.readAllString;
var fileSplit = fileStr.split($\n);
var launchpadOut = MIDIOut.newByName("Launchpad Pro", "Standalone Port");
fileSplit.size.postln;
fileSplit.do({|line|
	var lineSplit = line.split($ );
	var key = lineSplit[0].asInteger;
	var startBeat = lineSplit[2].asFloat;
	var recBuf = lineSplit[1].split($-).collect({|hitString|
		var sp = hitString.split($,);
		[sp[0].asFloat, sp[1].asInt, sp[2].asInt, sp[3].asInt, sp[4]]
	});
	recBuf.sort({|a, b| a[0] < b[0]});
	recBuf.do({|hit| hit.postln});

	//call createTask (assign to global var) and set it in bankMap (f)
	f[key][3] = r.(recBuf, startBeat);
	f[key][4] = lineSplit[1];

	//turn on lights of necessary banks
	setLight.(k[f[key][1]][f[key][0]], l[f[key][1]]);
});
)


56%12
83%12
((83-56)/12).asInt * 12
// ================================================================================================
(
//INDEXING FOR MODIFIED FULL-PAD KEYBOARD
var root = 60;
var scale = [0, 2, 4, 5 , 7 , 9, 11];
(1..8).do({|i|
	(1..8).do({|j|
		var ind = i*10 + j - 11;
		if(i > 1,
			{
				var shift = 0; //+- 5 for vertical, +- 1 for horizontal
				var noteInd = (ind-((i-1)*5));
				var note = root+noteInd;
				var isRoot = (note%12) == (root%12)
				var floorRoot = root + (((note-root)/12).asInt * 12);
				var isInScale = scale.collect({|n| floorRoot + n}).includes(note);
				noteInd.postln;  //pad -> index into chromatic list of numbers starting from root in bottom left

			},
			{ind.postln}
		);
	})
});
)
// ================================================================================================

(
var st = "0.0,64,118,3,on-0.0,70,118,1,on-0.0,70,120,2,on-0.111803,70,120,2,off-0.231101,64,118,3,off-0.0,70,118,1,off-0.407096,64,111,3,on-0.0,70,111,1,on-0.127192,64,111,3,off-0.0,70,111,1,off-0.122808,65,117,3,on-0.0,68,98,0,off-0.0,68,98,0,on-0.0,70,120,2,on-0.0,72,117,1,on-0.096141,68,98,0,on-0.015662,70,120,2,off-0.001363,68,98,0,off-0.022534,65,117,3,off-0.0,72,117,1,off-0.3643,65,118,3,on-0.0,72,118,1,on-0.183747,65,118,3,off-0.0,72,118,1,off-0.316253,63,117,3,on-0.0,72,118,1,on-0.294883,72,118,1,off-0.094903,63,117,3,off-0.110214,70,96,0,on-0.039907,70,96,0,off-0.210093,63,116,3,on-0.0,72,112,1,on-0.127904,63,116,3,off-0.000296,72,112,1,off-0.1218,63,116,3,on-0.0,72,116,1,on-0.142987,63,116,3,off-0.0,72,116,1,off-0.357013,63,120,3,on-0.0,72,118,2,on-0.0,72,120,1,on-0.13537,72,118,2,off-0.040893,63,120,3,off-0.0,72,120,1,off-0.323737,63,113,3,on-0.0,68,104,0,on-0.0,74,117,1,on-0.134925,63,113,3,off-0.223343,68,104,0,off-0.031518,74,117,1,off-0.110214,63,116,3,on-0.0,72,117,2,on-0.143854,72,117,2,off-0.007526,63,116,3,off-0.09862,74,116,1,on-0.127904,74,116,1,off-0.122096,62,116,3,on-0.0,70,119,2,on-0.0,72,121,2,on-0.0,74,116,1,on-0.158418,72,121,2,off-0.040768,70,119,2,off-0.111906,62,116,3,off-0.0,74,116,1,off-0.355575,68,115,0,on-0.083333,62,114,3,on-0.0,74,114,1,on-0.028532,68,115,0,off-0.090169,62,114,3,off-0.0,74,114,1,off-0.131299,63,118,3,on-0.0,72,108,1,on-0.0,74,120,2,on-1e-06,70,112,0,on-0.096008,70,112,0,off-0.048012,72,108,1,off-0.023165,74,120,2,off-0.127697,63,118,3,off-0.205117,72,121,1,on-0.199338,72,121,1,off-0.050662,63,112,3,on-0.1282,63,112,3,off-0.1218,63,108,3,on-0.0,70,113,1,on-0.0,72,121,2,on-1e-06,67,116,0,on-0.096039,67,116,0,off-0.038885,70,113,1,off-0.009096,63,108,3,off-0.015661,72,121,2,off-0.340318,63,121,3,on-0.0,70,116,1,on-0.15138,70,116,1,off-0.047958,63,121,3,off-0.300662,0,0,0,timeAfterLastHit";

var stringToBuf = {|melString|
	var buf = melString.split($-).collect({|hitString|
		var sp = hitString.split($,);
        sp.postln;
		[sp[0].asFloat, sp[1].asInt, sp[2].asInt, sp[3].asInt, sp[4]]
	});
	//buf.do({|b| b.postln;});
	buf
};

//112, 45, 21, 0, c1, c2, held, clear
~padColors
~basePadColors
[1,2].join(".")
(
var colorList = List.new;
var selectedList = List.new;
(8..1).do({|i|
    (1..8).do({|j|
        var colStr = switch(~basePadColors[i*10+j], 112, {"key"}, 45, {"root"}, 21, {"on"}, 0, {"nk"});
        var selStr = if(~padColors[i*10+j] == 21, {"sel"}, {"nsel"});
        colorList.add(colStr);
        selectedList.add(selStr);
    });
})
NetAddr("localhost", 12345).sendMsg("/processMatrices", , colorList.join("."), selectedList.join(".");
)


switch(8, 4, {true}, 5, {false}, )
stringToBuf.(st)

)