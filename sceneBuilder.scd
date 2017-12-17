//env vars for control
(
~truncateLoop = false;
)

//ACTIVE TODO TAGS: audioRecording

//todo audioRecording
/*
1. recorded loop doesn't start right after you stop recording
2. recorded loop doesn't seem to necessarily line up cleanly with metronome,
might need to re-trigger loop from SC to line up starts every time (if doing this,
make sure grooveve~ object is not in loop mode - that way if the loop is accidentally
recorded short you don't roll-over and play the starting bit twice. )
3. need to handle pad interaction edge cases of hitting other/same pads while in intermediate recording states
4. need to handle various ways of "clearing" loops when overwriting new loop to same pad.
*/

(
var launchpadOut, padTL, padBL, padTR, padBR, colorBL1, colorBR1, colorTL1, colorTR1, colorBL2, colorBR2, colorTL2, colorTR2, colorON, pads, padMap, madePadList, scales, roots, padOn, padOff, setPadLights, transposes, makePadList, indToNote_, indToNote, midiOut, launchPad, tempoClock, interruptLoopButtons, controlChanInd, tapTempoSetButton, tapTempoToggle, recordButton, lastTap, playMetronome, recordingMetronome, metronomeFunc, preRecordCount, preRecordLength, recordBuffer, color1, tlBanks, trBanks, blBanks, brBanks, banks, bankMap, recordingState, bankSet, bankToSaveTo, bankToRecording, recordColor, tempLoopTask, tempLoopString, createRecordedTask, playingBanks, metronomeFlashTask, recordingInterim, resetRecordingState, interruptLooping, controlChanButton, arrowButtons, color2, up, down, left, right, padsByChannel, recordingStartBeat, recordingEndBeat, truncateLoop, quantize, algOrderList, pythonOSCport, algResponseHandler, algButtons, quantizationLevels, algBanks, liveCodeHandler, newKeyButton, masterClockOSCport, masterClockTempoHandler, onDeckBuffers, algChannelsInfo, recieveBuffer, startChannel, stringToBuf, stopChannel, rootScaleHandler, newKeysTransposes, newKeysPadIndToNote, newKeysSetPadLights, playingNewKeys, newKeysChan, hitListToNoteList, noteListToHitList, quantizeButton, quantizeColor, quantized, controlHandler, masterClockBeatHandler, setBankMelody, receiveScene, tempoalignTempoButton, alignTempo, buttonForwarding, buttonForwardingButton, metronomeOut, padIndToColor, moduleLights, controlHandlerWrapper, processPort, isBankPad, isScenePad, calculateMajorityChannel, instrumentInput, scenes, scenePads, recordingScene, sceneRecordButton, sceneIsOnDeck, sceneColor, playScene, notRecordingColor, playMode, turnOnBank, turnOffBank, audioRecordingButton, audioLoopTarget, audioRecordingTarget, audioRecordingState, maxPort, audioClipColor, recordButtonFunc, padOnFunc;


//light switching variables
var setLight, ccLights, padColorState, cycleLight, lightIndex, cycleLight_BUTTON;

//MIDIClient.init;
//MIDIIn.connectAll;
launchpadOut = MIDIOut.new(8); //MIDIOut.newByName("Launchpad Pro", "Standalone Port");
launchpadOut.latency = 0;
midiOut = MIDIOut.newByName("IAC Driver", "Bus 2");
metronomeOut = MIDIOut.newByName("IAC Driver", "Bus 3");
midiOut.latency = 0;
metronomeOut.latency = 0;
pythonOSCport = NetAddr("localhost", 13371);
masterClockOSCport = NetAddr("localhost", 57120);
processPort = NetAddr("localhost", 12345);
maxPort = NetAddr("localhost", 5432);


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
        ["NEW LIGHT INDEX TRIGGER FROM SCENEBUILDER", ~lightIndex].postln;
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
        ["CHANGING TO SCENEBUILDER LIGHTS", msg[1], colorStateLog].postln;
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
["LIGHT INDEX SCENEBUILDER", ~lightIndex, lightIndex].postln;
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


//midiNote -> [bankInd, bankChan, isOn, loopTask/nil, loopString, loopType, playType]
//TODO: sceneBuilderplayType indicates none, loop, holdDown, or splice (-1, 0, 1, 2)
//loopType is either nil, \midi or \sample (a bank is playable IFF it has a loopType)
bankMap = Dictionary.new();
~tempCounter = 1;
(3..8).do({|i|
    (1..8).do({|j|
        bankSet.add((i*10)+j);
        //setLight.(j, color1[i]);
        bankMap.put((i*10)+j, [~tempCounter, -1, false, nil, nil, nil, nil]);
        ~tempCounter = ~tempCounter + 1;
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

scenes = List.fill(32, nil);
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
padOn = {|vel, note, chan, port|
    if((chan == 0) && (~lightIndex == lightIndex), {
        if(bankSet.includes(note), {
            var thisBank = bankMap[note];
            if((recordingState == 3) ,{
                if((audioRecordingState != 1), {
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
                    thisBank[4] = tempLoopString;
                    thisBank[5] = \midi;

                    playingBanks.add(note);

                    pythonOSCport.sendMsg("/saveLoop", thisBank[0], thisBank[4], note, thisBank[1]);
                    masterClockOSCport.sendMsg("/saveLoop", thisBank[0], thisBank[4], note, thisBank[1]);
                    masterClockOSCport.sendMsg("/metaInfoSaveRequest", thisBank[0], thisBank[2]);

                    "D sceneBuilder".postln;
                    resetRecordingState.();
                });
                //TODO audioRecording - stop audioLoop in the same slot?
            },
            {

                if((audioRecordingState == 1),
                    {
                        audioRecordingTarget = note;
                        audioRecordingState = 2;
                        thisBank[5] = \sample;
                        //TODO audioRecording - stop/wipe midiLoop in the same slot?
                    },
                    {
                        "MANUAL BANK PLAY/STOP".postln;
                        if(thisBank[5] != nil, {
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
                                        {turnOnBank.(thisBank, note)},
                                        {turnOffBank.(thisBank, note)}
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
                    }
                );
            });

        });
        if(scenePads.includes(note), {
            var sceneInd = note-20; //todo - change when SCENE PAGES are implemented
            if(recordingScene,
                {
                    scenes[sceneInd] = bankMap.deepCopy;
                    setLight.(note, sceneColor);
                    pythonOSCport.sendMsg("/saveScene", sceneInd);
                },
                {if(scenes[sceneInd].isNil.not, {
                    playScene.(scenes[sceneInd], sceneInd);
                    pythonOSCport.sendMsg("/metaInfoLoadRequest", sceneInd); //TODO - probably want this in playScene()
                })};
            );
        });
    });
};
padOnFunc = MIDIFunc.noteOn(padOn, nil, nil, launchPad.uid);

//msg[1] is pad index
OSCFunc.new({|msg, time, addr, recvPort|
    padOn.(nil, msg[1].asInt, nil, nil);
}, "/padHit");

padOff = MIDIFunc.noteOff({|vel, note, chan, port|
    if((chan == 0) && (~lightIndex == lightIndex), {
        if(bankSet.includes(note), {
            var thisBank = bankMap[note];
            if(playMode == 1, {
                if(thisBank[2], {turnOffBank.(thisBank, note)});
            });
        });
    });
}, nil, nil, launchPad.uid);


turnOnBank = {|thisBank, note|
    ["TURNING ON", note].postln;
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
    switch(thisBank[5],
        \midi, {thisBank[3].start},
        \sample, {maxPort.sendMsg("/samplerControl", thisBank[0], "playStart", 0)}
    );
    thisBank[2] = true;
    playingBanks.add(note);
    pythonOSCport.sendMsg("/loopPlay", thisBank[1], thisBank[0], true); //mark python loop-info as playing
};

turnOffBank = {|thisBank, note|
    midiOut.allNotesOff(thisBank[1]);
    //["TURNING OFF", note].postln;
    switch(thisBank[5],
        \midi, {thisBank[3].stop},
        \sample, {maxPort.sendMsg("/samplerControl", thisBank[0], "playStop", 0)}
    );
    thisBank[6] = nil;
    thisBank[2] = false;
    setLight.(note, switch(thisBank[5], \midi, {color1[thisBank[1]]}, \sample, {audioClipColor}));
    playingBanks.remove(note);
    pythonOSCport.sendMsg("/loopPlay", thisBank[1], thisBank[0], false); //mark python loop-info as stopped

};

//msg[1] is bank index, msg[2] is whether to turn bank on or off
OSCFunc.new({|msg, time, addr, recvPort|
    //indexes 0-7 mapped to top row - 81-88
    var bankKey = 81+msg[1].asInt;
    var bank = bankMap[bankKey];
    if(bank[3].isNil.not, {
        if(msg[2].asSymbol == \off, {
            turnOffBank.(bank, bankKey);
        });
        if(msg[2].asSymbol == \on, {
            turnOnBank.(bank, bankKey);
        });
    });
}, "/toggleBank");

//msg[1] is channelIndex index
OSCFunc.new({|msg, time, addr, recvPort|
    midiOut.allNotesOff(msg[1].asInt);
}, "/turnOffChannel");


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

MIDIFunc.cc({|vel, note, chan, port|
    if((note == recordButton) && (vel == 127), {recordButtonFunc.()});
}, nil, nil, instrumentInput.uid);

OSCFunc.new({|msg, time, addr, recvPort|
    recordButtonFunc.();
}, "/recordButton");

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
~quantizeDebugPrint = false;
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

    if(~quantizeDebugPrint, {"PRE NOTES".postln});
    newBuf = hitListToNoteList.(recBuf, startBeat);
    //newBuf.do({|note| note.postln});
    if(~quantizeDebugPrint, {"B".postln});
    newBuf = noteListToHitList.(newBuf);
    if(~quantizeDebugPrint, {
        if(recBuf == newBuf, {"MATCH".postln}, {
            "NO MATCH".postln;
            (0..recBuf.size).do({|ind|
                [ind+":  ", recBuf[ind], "      ", newBuf[ind]].postln
            });
        });
    });
    if(~quantizeDebugPrint, {"POST NOTES".postln});

    //todo - quantize based on "notes" instead of hits - shift noteOn but keep note duration the same
    newBuf = hitListToNoteList.(recBuf, startBeat);
    if(~quantizeDebugPrint, {["noteList", newBuf.size].postln});
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
    if(~quantizeDebugPrint, {["notes per beat", notesPerBeat.collect({|a| a.size})].postln});
    notesPerBeat.do({|hits|
        var quantLists = List.new();
        var bestList = [List.new(), 1];
        var quantHitList;
        quantDivArray.do({|div|
            var quantList = List.new();
            var error = 0; //ignore noteOff messages for error calculation
            hits.do({|hit| quantList.add(hit[0].floor + ((hit[0]%1 * div).round / div))});
            (0..(hits.size-1)).do({|i|
                error = error + (hits[i][0] - quantList[i]).abs;
                if(~quantizeDebugPrint, {"error".postln});
            });
            if(~quantizeDebugPrint, {[(hits.size-1), hits[0][0].floor, error, div, error/div, hits.collect({|hit| hit[0]})].postln});
            quantLists.add([quantList, error]);
        });
        if(~quantizeDebugPrint, {"-----".postln});
        quantLists.do({|listErr| if(listErr[1] < bestList[1], {bestList = listErr})});
        quantHitList = List.fill(hits.size, {|i|
            var newHit = List.newFrom(hits[i]);
            newHit[0] = bestList[0][i];
            newHit
        });
        quantizedNotes.add(quantHitList);
    });
    if(~quantizeDebugPrint, {["num quantized notes pre", quantizedNotes].postln});
    quantizedNotes = quantizedNotes.inject(List.new(), _++_);
    if(~quantizeDebugPrint, {["num quantized notes post", quantizedNotes].postln});
    //quantizedNotes.do({|note| note.postln});
    //todo - quant end

    //TODO - something still messed up with long held notes
    //TOGGLE QUANTIZATION HERE
    if(quantized, {
        var loopDur = if(~truncateLoop,  melodyEndingBeat - startBeat, endBeat - startBeat);
        var maxEnd = 0;

        if(~quantizeDebugPrint, {["timeAFterLastHit", startBeat, endBeat, melodyEndingBeat].postln});

        //modify noteEnds and timeAfterLastBeat s.t. it is still within an integral beat length
        quantizedNotes.do({|note|
            if((note[0] + note[4]) > loopDur, {note[4] = loopDur - 0.001});
            if((note[0] + note[4]) > maxEnd, {maxEnd = note[0] + note[4]});
        });

        //recalculate timeAfterLastHit
        timeAfterLastHit = loopDur - maxEnd;

        recBuf = noteListToHitList.(quantizedNotes);


    });

    if(~quantizeDebugPrint, {timeAfterLastHit.postln});

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
            //["HIT sceneBuilder", hit].postln;

            hit[0].wait;

            if(interruptLooping[chan].not, {
                if(hit[4] == "on", {midiOut.noteOn(hit[3], hit[1], hit[2]);});
                if(hit[4] == "off", {midiOut.noteOff(hit[3], hit[1], hit[2])});
            });
            ind = ind+1; //TODO - should this be after the switch to the ondeck buffer?

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

audioRecordingButton = 49;
audioRecordingTarget = -1;
//0 - nothing, 1 - pre select bank, 2 - pre record trigger, 3 pre record, 4 recording, 5 pre rec-stop
//TODO audioRecording
audioRecordingState = 0;
audioClipColor = 9; //colorVal
setLight.(audioRecordingButton, audioClipColor);




recordButtonFunc = {
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
        recordingEndBeat = tempoClock.beats.ceil;

        //TODO: handle cases where multiple inst hits in a recBuf, or when there's no noteOns recorded
        if(recordBuffer.size == 0,
            {
                resetRecordingState.();
            },
            {
                recBuf = quantize.(recordBuffer, quantizationLevels, recordingStartBeat, recordingEndBeat);

                tempLoopString = recBuf.collect({|item| item.join(",")}).join("-");
                tempLoopTask = createRecordedTask.(recBuf);
                tempoClock.sched(tempoClock.timeToNextBeat, {tempLoopTask.start; nil;});
            }
        );
    });
};

OSCFunc.new({|msg, time, addr, recvPort|
    playMetronome = playMetronome.not;
}, "/toggleMetronome");


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
    if((note == audioRecordingButton) && (vel == 127), {
        switch(audioRecordingState,
            0, {audioRecordingState = 1},
            2, {
                audioRecordingState = 3;
            },
            4, {
                audioRecordingState = 5;
            }
        );
    });
    if((note == tapTempoToggle) && (vel == 127), {playMetronome = playMetronome.not});
    if((note == recordButton) && (vel == 127), {recordButtonFunc.()});
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
        // ["MULTILOOP BUTTON CYCLE HIT", ~lightIndex, lightIndex].postln;
        if(~cycling, {cycleLight.()})
        // if(~truncateLoop, {setLight.(cycleLight_BUTTON, 45)}, {setLight.(cycleLight_BUTTON, 0)});
        // ~truncateLoop = ~truncateLoop.not; //light on means NOT TRUNCATING*/
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


playScene = {|bankMapInstance, sceneInd|
    if(sceneIsOnDeck.not, {
        sceneIsOnDeck = true;
        tempoClock.sched(tempoClock.timeToNextBeat, {
            //todo sceneBuilder - turn off current scene
            "SCENE a sceneBuilder".postln;
            (0..3).do({|i| midiOut.allNotesOff(i)});
            //"SCENE b sceneBuilder".postln;
            bankMap.values.do({|bank|
                if(bank[3].isNil.not, {bank[3].stop; bank[3].free});
            });
            //"SCENE c sceneBuilder".postln;
            bankMap = bankMapInstance.deepCopy;
            playingBanks.clear;
            //midiNote -> [bankButton, bankChan, isOn, loopTask/nil, loopString, playType, algMelodyString]
            bankMap.keys.do({|padInd|
                var bank = bankMap[padInd];
                //turn on/off light
                setLight.(padInd, bank[3].isNil.if(0, color1[bank[1]]));
                //["SCENE d sceneBuilder", padInd].postln;
                //recreate task from string (maybe there's closure issues when trying to play the old task?)
                if(bank[4].isNil.not, { bank[3] = createRecordedTask.(stringToBuf.(bank[4])) });
                //["SCENE e sceneBuilder", padInd].postln;
                //play and add to playing banks
                if(bank[2], {
                    //TODO sceneBuilder - recreate task?
                    bank[3].play;
                    playingBanks.add(padInd);
                });
                //["SCENE f sceneBuilder", padInd].postln;
            });
            sceneIsOnDeck = false;
            //pythonOSCport.sendMsg("/scenePlayed", sceneInd); what is this for?
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
    buffer.do({|hit| if(chanCount[hit[3]].isNil,
        {chanCount[hit[3]] = 1}, {chanCount[hit[3]] = chanCount[hit[3]]+1})});
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



////midiNote -> [bankInd, bankChan, isOn, loopTask/nil, loopString, loopType, playType]
setBankMelody = {|button, hitString, playing, bankMapInstance|

    //todo - enable this to minimize latency?
    //melodyTask = createRecordedTask.(stringToBuf.(hitString));

    var bank = bankMapInstance[button];
    var buf = stringToBuf.(hitString);
    bank[1] = calculateMajorityChannel.(buf);
    bank[2] = playing;
    bank[3] = createRecordedTask.(buf);
    bank[4] = hitString;
    bank[5] = \midi;
    bank[6] = "";
    setLight.(button, color1[bank[1]]);
    ["bank melody set for", button, bank].postln;
};

// msg[1] is button, msg[2] is string
OSCFunc({|msg, time, addr, recvPort|
    var button = msg[1].asInt;
    var bank = bankMap[button];
    if(bank[3].isNil.not, {
        bank[2] = false;
        bank[3].stop;
        bank[3].free;
        midiOut.allNotesOff(bank[1]);
        bank[1] = -1;
        bank[3] = nil;
        bank[4] = nil;
        bank[5] = nil;
        bank[6] = "";
        setLight.(button, 0);
    });
    setBankMelody.(button, msg[2].asString, false, bankMap);
}, "/setBankMelody");

//msg = [/address, melody/info-strList, sceneNumber] - melodyInfoStr

receiveScene = {|msg, time, addr, recvPort|
    ["RECIEVED SCENE", msg[2]].postln;
    if(msg[1].asSymbol != \none,
        {
            //set roots and scales
            var count = 0;
            var bankMapInstance = bankMap.deepCopy;

            ["SCENE IS NON NULL", msg[2]].postln;
            bankMapInstance.keys.do({|button|
                var bank = bankMapInstance[button];
                var stopFunc = {
                    //["STOP FUNC NOW", bank[3].isNil].postln;
                    if(bank[3].isNil.not, {
                        bank[2] = false;
                        bank[3].stop;
                        bank[3].free;
                        midiOut.allNotesOff(bank[1]);
                        bank[1] = -1;
                        bank[3] = nil;
                        bank[4] = nil;
                        bank[5] = nil;
                        bank[6] = "";
                        setLight.(button, 0);
                    });
                    nil;
                };
                tempoClock.sched(tempoClock.timeToNextBeat-0.01, stopFunc);
            });

            ["ALL LOOPS STOPPED FOR SCENE", msg[2]].postln;

            //split string and set banks
            msg[1].asString.split($:).do({|bankStr|
                if(bankStr.asSymbol != \none,
                    {
                        var split, bankInfo;
                        split = bankStr.split($ );
                        ["bankCount", count, split[0]].postln;
                        count = count+1;
                        bankInfo = [split[0].asInt, split[1], (split[2].asInt == 1)];
                        ["setBankMelodyArgs", bankInfo[0], bankInfo[2], bankInfo[1]].postln;
                        setBankMelody.(bankInfo[0], bankInfo[1], bankInfo[2], bankMapInstance);
                    }
                );
            });
            scenes[msg[2].asInt] = bankMapInstance.deepCopy;
            setLight.(20+msg[2], sceneColor); //todo - change when SCENE PAGES are implemented
        },
        {
            scenes[msg[2].asInt] = nil;
            setLight.(20+msg[2], 0); //todo - change when SCENE PAGES are implemented
        }
    );
};
OSCFunc(receiveScene, "/sendScene");



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
    masterClockOSCport.sendMsg("/resetRecordingState_algKeys", 1);
    r
};

metronomeFlashTask = Task({
    if(recordingMetronome || (tempLoopTask != nil),
        {setLight.(recordButton, (recordingState==2).if(17,recordColor))});
    playingBanks.do({|bNote|
        var color = switch(bankMap[bNote][5],
            \midi, {color1[bankMap[bNote][1]]},
            \sample, {audioClipColor}
        );
        setLight.(bNote, color);
    });
    if([2,3,4,5].includes(audioRecordingState), {setLight.(audioRecordingTarget, recordColor)});
    if([4,5].includes(audioRecordingState), {setLight.(audioRecordingButton, recordColor)});
    (tempoClock.beatDur/2).wait;
    if(recordingMetronome || (tempLoopTask != nil), {setLight.(recordButton, 0)});
    playingBanks.do({|bNote| setLight.(bNote, 0)});
    if([2,3,4,5].includes(audioRecordingState), {setLight.(audioRecordingTarget, 0)});
    if([4,5].includes(audioRecordingState), {setLight.(audioRecordingButton, 0)});
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
    if(audioRecordingTarget > 0, {
        switch(audioRecordingState,
            3, {
                audioRecordingState = 4;
                maxPort.sendMsg("/samplerControl", bankMap[audioRecordingTarget][0], "record", 1);
            },
            5, {
                audioRecordingState = 0;
                maxPort.sendMsg("/samplerControl", bankMap[audioRecordingTarget][0], "record", 0);
                maxPort.sendMsg("/samplerControl", bankMap[audioRecordingTarget][0], "playStart", 0);
                setLight.(audioRecordingTarget, audioClipColor);
                setLight.(audioRecordingButton, audioClipColor);
                playingBanks.add(audioRecordingTarget);
                bankMap[audioRecordingTarget][2] = true;
                bankMap[audioRecordingTarget][5] = \sample;
                audioRecordingTarget = -1;
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
w = Window.new.front;
c = CompositeView(w, Rect(10, 10, 300, 300));
d = DragSink(c, Rect(0, 0, 80, 80)).action_({|v|
    var files = [];
    var pathString = v.object;
    pathString.postln;
    p = PathName( pathString );
    m = SimpleMIDIFile.read(p.fullPath);
});
d.name = "aaa";
d.keyDownAction = {|view, char, modifier, unicode, keycode, key|
    [view.name, char, modifier, unicode, keycode, key].postln;
    false;
};
t = TextField(c, Rect(20, 10, 40, 20)); //length of loop
u = TextField(c, Rect(4, 50, 70, 20)); //filename
u.keyDownAction = {|view, char, modifier, unicode, keycode, key|
    [view.name, char, modifier, unicode, keycode, key].postln;
    //if(key =
    false;
};
)
d.dump

m.midiEvents
m.dump
m.endOfTrack
m.adjustEndOfTrack(0, 96*4)
m.midiTracks
(m.metaEvents[3].asString).postln