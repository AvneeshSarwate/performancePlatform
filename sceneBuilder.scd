//env vars for control
(
~truncateLoop = false;
)

(
var launchpadOut, padTL, padBL, padTR, padBR, colorBL1, colorBR1, colorTL1, colorTR1, colorBL2, colorBR2, colorTL2, colorTR2, colorON, pads, padMap, madePadList, scales, roots, padOn, padOff, setPadLights, transposes, makePadList, indToNote_, indToNote, midiOut, launchPad, tempoClock, interruptLoopButtons, controlChanInd, tapTempoSetButton, tapTempoToggle, recordButton, lastTap, playMetronome, recordingMetronome, metronomeFunc, preRecordCount, preRecordLength, recordBuffer, color1, tlBanks, trBanks, blBanks, brBanks, banks, bankMap, recordingState, bankSet, bankToSaveTo, bankToRecording, recordColor, tempLoopTask, tempLoopString, createRecordedTask, playingBanks, metronomeFlashTask, recordingInterim, resetRecordingState, interruptLooping, controlChanButton, arrowButtons, color2, up, down, left, right, padsByChannel, recordingStartBeat, recordingEndBeat, truncateLoop, quantize, algOrderList, pythonOSCport, algResponseHandler, algButtons, quantizationLevels, algBanks, liveCodeHandler, newKeyButton, masterClockOSCport, masterClockTempoHandler, onDeckBuffers, algChannelsInfo, recieveBuffer, startChannel, stringToBuf, stopChannel, rootScaleHandler, newKeysTransposes, newKeysPadIndToNote, newKeysSetPadLights, playingNewKeys, newKeysChan, hitListToNoteList, noteListToHitList, quantizeButton, quantizeColor, quantized, controlHandler, masterClockBeatHandler, setBankMelody, receiveScene, tempoalignTempoButton, alignTempo, buttonForwarding, buttonForwardingButton, metronomeOut, padIndToColor, moduleLights, controlHandlerWrapper, processPort, isBankPad, isScenePad, calculateMajorityChannel, instrumentInput, scenes, scenePads, recordingScene, sceneRecordButton, sceneIsOnDeck, sceneColor, playScene, notRecordingColor, playMode;

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

algOrderList = List.new();

recordBuffer = List.new(200);

colorTL1 = 39;
colorTR1 = 112;
colorBL1 = 4;
colorBR1 = 83;
color1 = [colorTL1, colorTR1, colorBL1, colorBR1]; //colorVal


padIndToColor = Dictionary.new();

colorON = 13;

bankSet = Set.new();

//midiNote -> [bankButton, bankChan, isOn, loopTask/nil, loopString, playType, algMelodyString]
//TODO: sceneBuilderplayType indicates none, loop, holdDown, or splice (-1, 0, 1, 2)
bankMap = Dictionary.new();
(3..8).do({|i| (1..8).do({|j|
    bankSet.add((i*10)+j);
    //setLight.(j, color1[i]);
    bankMap.put((i*10)+j, [(i*10)+j, -1, false, nil, nil, nil, nil]); //TODO: reverse i,j here and everywhere else
})});
z = bankMap;
bankSet.do({|i| setLight.(i, 0)});
playingBanks = Set.new();

quantizeButton = 8;
quantizeColor = 8;
quantized = false;


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

onDeckBuffers = List.fill(16, {nil;});

//[task, midiChanInd]
algChannelsInfo = List.fill(16, {[nil, nil];});

scenes = List.fill(8, nil);
scenePads = (21..28);
sceneRecordButton = 59;
recordingScene = false;
//setLight  TODO: sceneBuiler set scene record button initial light
notRecordingColor = 17; //colorVal
setLight.(sceneRecordButton, notRecordingColor);
sceneIsOnDeck = false; //prevents wierd race conditions/overlap from hitting play scene twice before metronome tick
sceneColor = 3; //colorVal

playMode = 0;

launchPad = MIDIClient.sources.select({|elem| (elem.name == "Standalone Port")
    && (elem.device == "Launchpad Pro")})[0];
instrumentInput = MIDIClient.sources.select({|elem| (elem.name == "Bus 7")
    && (elem.device == "IAC Driver")})[0];
[launchPad, MIDIClient.sources[2]].postln;
padOn = MIDIFunc.noteOn({|vel, note, chan, port|
    if(bankSet.includes(note), {
        var thisBank = bankMap[note];
        if(recordingState == 3,
            {
                "A sceneBuilder".postln;
                //save the recorded buffer to the appropriate bank
                if(thisBank[3] != nil, {
                    thisBank[3].stop;
                    thisBank[3].free;
                });
                "B sceneBuilder".postln;
                thisBank[1] = calculateMajorityChannel.(stringToBuf.(tempLoopString));
                "C sceneBuilder".postln;
                thisBank[2] = true;
                thisBank[3] = tempLoopTask;
                thisBank[4] = note + tempLoopString + recordingStartBeat;
                thisBank[5] = 0;

                playingBanks.add(note);
                "D sceneBuilder".postln;
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
                    if(playMode == 0, {
                        tempoClock.sched(tempoClock.timeToNextBeat, {
                            if(thisBank[2].not,
                                {turnOnBank.(thisBank)},
                                {turnOffBank.(thisBank)}
                            ); //TODO sceneBuilder - issues if pressing the bank button twice before metronome?
                            "TEMPOCLOCK FUNC RUN".postln;
                            //setLight.(note, 0);
                            nil;
                        });
                    });
                    if(playMode == 1, {
                        turnOnBank.(thisBank);
                    });
                    if(playMode == 2, {

                    });
                });
        });
    });
    if(scenePads.includes(note), {
        if(recordingScene,
            {scenes[note-20] = bankMap.deepCopy; setLight.(note, sceneColor)},
            {if(scenes[note-20].isNil.not, {playScene.(scenes[note-20])})};
        );
    });
}, nil, nil, launchPad.uid);

padOff = MIDIFunc.noteOff({|vel, note, chan, port|
    if(bankSet.includes(note), {
        var bank = bankMap[note];
        if(playMode == 1, {
            if(thisBank[2], {turnOffBank.(thisBank)});
        });
    });
}, nil, nil, launchPad.uid);


turnOnBank = {|thisBank|
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
};

turnOffBank = {|thisBank|
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

};


a = {|vel, note, chan, port|
    midiOut.noteOn(chan, note, vel);
    if(recordingMetronome, {recordBuffer.add([tempoClock.beats, note, vel, chan, "on"])});
};
MIDIFunc.noteOn(a, nil, nil, instrumentInput.uid);

b = {|vel, note, chan, port|
    midiOut.noteOff(chan, note, vel);
    if(recordingMetronome, {recordBuffer.add([tempoClock.beats, note, vel, chan, "off"])});
};
MIDIFunc.noteOff(b, nil, nil, instrumentInput.uid);

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
    //t = tempoClock;
    tempoClock.schedAbs(1, metronomeFunc);
    "MULTILOOP ONE SHOT".postln;
}, "/masterClockBeat").oneShot;
masterClockBeatHandler = {|msg, time, addr, recvPort|
    //["MULTILOOP BEAT", tempoClock.beats].postln;
};
OSCFunc(masterClockBeatHandler, "/masterClockBeat");
tapTempoSetButton = 69;
tapTempoToggle = 79;
recordButton = 89;
recordColor = 5; //colorVal
setLight.(recordButton, recordColor);
//setLight.(quantizeButton, 0);
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
    if((note == tapTempoSetButton) && (vel == 127), {
        var now = TempoClock.beats;
        if((now - lastTap) < 2, {masterClockOSCport.sendMsg("/uploadTempo", now - lastTap, alignTempo)});
        lastTap = now;
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
            if(recordBuffer.size == 0,
                {
                    resetRecordingState.();
                },
                {
                    chan = recordBuffer[0][3];

                    recBuf = quantize.(recordBuffer, quantizationLevels, recordingStartBeat, recordingEndBeat);

                    tempLoopString = recBuf.collect({|item| item.join(",")}).join("-");
                    tempLoopTask = createRecordedTask.(recBuf);
                    tempoClock.sched(tempoClock.timeToNextBeat, {tempLoopTask.start; nil;});
                }
            );
        });
    });
    if((note == sceneRecordButton) && (vel == 127), {
        recordingScene = recordingScene.not;
        setLight.(sceneRecordButton, recordingScene.if(recordColor, notRecordingColor));
    });
    if((note == quantizeButton) && (vel == 127), {
        /*quantized = quantized.not;
        if(quantized,
        {setLight.(quantizeButton, quantizeColor)},
        {setLight.(quantizeButton, 0)}
        );*/
    });
    if(arrowButtons.includes(note) && (vel == 127), {

    });
    //MULTIPLE ALG BUTTONS CAN BE HELD DOWN
    //THEIR ORDER WILL SPECIFY A "pipeline" of transformations
    //if alg button, add/remove from list depending on button up/down
    if((note == cycleLight_BUTTON) && (vel !=0), {
        /*// ["MULTILOOP BUTTON CYCLE HIT", ~lightIndex, lightIndex].postln;
        //if(~cycling, {cycleLight.()})
        if(~truncateLoop, {setLight.(cycleLight_BUTTON, 45)}, {setLight.(cycleLight_BUTTON, 0)});
        ~truncateLoop = ~truncateLoop.not; //light on means NOT TRUNCATING*/
    });
};
controlHandlerWrapper = {|vel, note, chan, port|
    ~lock.wait;
    if((chan == 0) && (~lightIndex == lightIndex) && (vel != 0), {
        //["LIGHT INDEX MULTILOOP", ~lightIndex, lightIndex, SystemClock.beats].postln;
        controlHandler.(vel, note, chan, port)
    });
    ~lock.signal;
};
MIDIFunc.cc(controlHandlerWrapper, nil, nil, launchPad.uid);


playScene = {|bankMapInstance|
    if(sceneIsOnDeck.not, {
        sceneIsOnDeck = true;
        tempoClock.sched(tempoClock.timeToNextBeat, {
            bankMap = bankMapInstance.deepCopy;
            playingBanks.clear;
            //midiNote -> [bankButton, bankChan, isOn, loopTask/nil, loopString, playType, algMelodyString]
            bankMap.keys.do({|padInd|
                var bank = bankMap[padInd];
                //turn on/off light
                setLight.(padInd, bank[3].isNil.if(0, color1[bank[1]]));

                //recreate task from string (maybe there's closure issues when trying to play the old task?)
                if(bank[4].isNil.not, {bank[3] = createRecordedTask.(stringToBuf.(bank[4]))});

                //play and add to playing banks
                if(bank[2], {
                    //TODO sceneBuilder - recreate task?
                    bank[3].play;
                    playingBanks.add(padInd);
                });
            });
            sceneIsOnDeck = false;
        });
    });
};

stringToBuf = {|melString|
    var buf = melString.split($-).collect({|hitString|
        var sp = hitString.split($,);
        [sp[0].asFloat, sp[1].asInt, sp[2].asInt, sp[3].asInt, sp[4]]
    });
    //buf.do({|b| b.postln;});
    buf
};

calculateMajorityChannel = {|buffer|
    var chanCount = Dictionary.new;
    var maxChan = [-1, -1]; //chan, count
    buffer.do({|hit| if(chanCount[hit[3]].isNil, {chanCount[hit[3]] = 1}, {chanCount[hit[3]] = chanCount[hit[3]]+1})});
    chanCount.keys.do({|key| if(chanCount[key] > maxChan[1], {maxChan = [key, chanCount[key]]})});
    maxChan[0];
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