(
var midiOut, pythonOSCport, channelPatternMap, chanBackupPatMap, channelInd, drumTypes, startPattern, playStepGenerator, recieveBackupPattern, stopPattern, patternRead, timeListToDurationList, sendSample, masterTempoClock, tempoClockMap, loopStartFunctions, masterClockBeat, masterClockTempoHandler, maxPort, heldHitTasks, maxMidiOut;
var broadcastOSCport, tempo, maxBeatFunc, lastMasterBeat, linkDrift;

var channelMap, startWaveHandler, stopWaveHandler, startWave, stopWave;
var sinwav = {|fr,ph,am,sh, time| (sin((pi*fr*time)+ph)*am)+sh};
var coswav = {|fr,ph,am,sh, time| (cos((pi*fr*time)+ph)*am)+sh};

var sqr = {|time| var tm = time%2; if(tm<1, 1, -1)};
var sqrwav = {|fr,ph,am,sh, time| (sqr.((fr*time)+ph)*am)+sh};

var saw = {|time| var tm = time%2; tm-1};
var sawwav = {|fr,ph,am,sh, time| (saw.((fr*time)+ph)*am)+sh};

var tri = {|time| var tm = time%2; case {tm<0.5} {2*tm} {tm<1.5} {2-(2*tm)} {tm>=1.5} {2*tm-4}};
var triwav = {|fr,ph,am,sh, time| (tri.((fr*time)+ph)*am)+sh};

var calcStr = "triwav.(1,0,1,triwav.(3,0,sinwav.(sawwav.(5,0,1,0,time),0,0.333333333333,0.0,time),0.0,time),time)";
var createCalcFunc = {|calcString|
    var prepFunc = ("{|sinwav, coswav, sqrwav, sawwav, triwav| {|time|" + calcString + "}};").interpret;
    prepFunc.(sinwav, coswav, sqrwav, sawwav, triwav);
};

var func = createCalcFunc.(calcStr);
func.(1);


//cc ind -> waveTask
channelMap = Dictionary.new;
//~chanDebugMap = Dictionary.new;
//msg[1] is cc ind, msg[2] is calcString, msg[3] is "OSC" or "midi"
startWave = {|msg, time, addr, recvPort|
    var waveTask = Task({
        var func = createCalcFunc.(msg[2].asString);
        var ccIndOrWaveAddr = msg[1];
        ~debugf = func;
        ["WAVE TASK STARTED", msg[3].asString].postln;
        {
            if(msg[3].asString == "midi",
                {
                    var rawVal = (func.(masterTempoClock.beats) + 64).round;
                    var val = max(min(127, rawVal), 0);
                    //[rawVal, val, func.(0.5), msg[2].asString, masterTempoClock.beats].postln;
                    midiOut.control(0, ccIndOrWaveAddr.asInt, val);
                },
                //else its "osc"
                {
                    [ccIndOrWaveAddr.asString, func.(masterTempoClock.beats)].postln;
                    maxPort.sendMsg(ccIndOrWaveAddr.asString, func.(masterTempoClock.beats))
                }
            );
            0.02.wait;
        }.loop;
    });
    msg.postln;
    waveTask.start;
    if(channelMap[msg[1]].isNil.not, {
        channelMap[msg[1]].stop;
        channelMap[msg[1]].free;
    });
    channelMap[msg[1]] = waveTask;
    //~chanDebugMap[msg[1]] = [createCalcFunc.(msg[2].asString), msg[2].asString];
};
startWaveHandler = OSCFunc(startWave, "/startWave");

//msg[1] is cc ind OR waveOSCAddress
stopWave = {|msg, time, addr, recvPort|
    msg.postln;
    if(channelMap[msg[1]].isNil.not, {
        channelMap[msg[1]].stop;
        channelMap[msg[1]].free;
    });
    channelMap[msg[1]] = nil;
};
stopWaveHandler = OSCFunc(stopWave, "/stopWave");

MIDIClient.init;
MIDIIn.connectAll;

masterTempoClock = TempoClock.new(1);
lastMasterBeat = 0;
linkDrift = 0;
broadcastOSCport = NetAddr("localhost", 57120);


//msg[1] is the new tempo in beats per MINUTE (tempo clock is bpSEC)
maxBeatFunc = {|msg, time, addr, recvPort|
    var newTempo = msg[1].asFloat;
    //["max LINK BEAT", newTempo].postln;

    var beat = masterTempoClock.beats;
    linkDrift = linkDrift + (1 - (beat - lastMasterBeat));
    //["BEATS", beat-lastMasterBeat, linkDrift, beat].postln;
    lastMasterBeat = beat;

    if(newTempo != tempo, {
        tempo = newTempo;
        masterTempoClock.tempo = tempo/60;
        tempoClockMap.values.do({|clock| clock.tempo = tempo/60});
    });
};


//msg[1] is the new tempo in beats per MINUTE (tempo clock is bpSEC)
OSCFunc({|msg, time, addr, recvPort|
    tempo = msg[1].asFloat;
    masterTempoClock = TempoClock.new(tempo/60);
    OSCFunc(maxBeatFunc, "/maxLink");
}, "/maxLink").oneShot;



midiOut = MIDIOut.newByName("IAC Driver", "Bus 3");
midiOut.latency = 0;
maxMidiOut = MIDIOut.newByName("to Max 1", "to Max 1");
maxMidiOut.latency = 0;
pythonOSCport = NetAddr("localhost", 34345);
maxPort = NetAddr("localhost", 5432);

//masterTempoClock = TempoClock.new(1);
channelPatternMap = Dictionary();
chanBackupPatMap = Dictionary();
channelInd = Dictionary();
tempoClockMap = Dictionary();
loopStartFunctions = Dictionary();
heldHitTasks = Dictionary();

//LATENCYFIX - latencyCompMap - a map chanInd -> preDelay
//because sendSample is delaying MIDI noteOn by x ms, we need to start the sequence x ms early
//however, if there is < x ms before the next metronome hit when we start a sequence,
//we use whatever predelay k we can, and then save the leftovers (x-k) to use before the next sequence


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

            //["PLAYSTEP", ~sentCount, masterTempoClock.beats, step[1]].postln;
            step[1].do({|samp| sendSample.(samp)});

            //["STEP", i, ind, tempoClockMap[i].beats%1, step].postln;

            //if 2nd to last step, send request for next pattern TODO: won't work for patterns len 1?
            if(ind == (patList.size-2), {pythonOSCport.sendMsg("/pydalGetUpdate-"++i)});

            //if last step (or < 20 ms from end?), set backupPat to actual pattern
            if(ind == (patList.size-1), {
                //"DID BACKUP".postln;
                channelPatternMap[i] = chanBackupPatMap[i]
            });

            //update indexes appropriately TODO: should the index always be set to zero here?
            channelInd[i] = (ind+1)%patList.size;

            //LATENCYFIX - adjust this number by latencyCompMap and save the leftover latency
            //return (d) - i.e. schedule next step on channel
            retVal = dur;
            //["RETVAL  ", retVal, ind].postln;
        });
        //["RETVAL  ", retVal].postln;
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
    maxPort.sendMsg("/sampLoop/stopAll", 1);
    ["STOP PATTERN", channelPatternMap.keys.includes(msg[1]), msg[1]].postln;
};
OSCFunc(stopPattern, "/pydalStop");


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

    //LATENCYFIX - adjust this number by latencyCompMap and save the leftover latency
    1
};
masterTempoClock.sched(masterTempoClock.timeToNextBeat, masterClockBeat);

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

//TODO - this breaks for patterns like read("a a", 4) - renders to [(0, {"a"}, (2.0, {"a"})]
//and causes double triggering and weird osc latency issues
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

~ableton = false;
~max = true;
~sentCount = 0;
//LATENCYFIX - this method contains a task that sends start-pos OSC, then noteOn midi x ms later
sendSample = {|drumStr|
    if(drumStr.asString != "~", {
        var bank, start, end, duration, bufToUse, startSecs, banksToTurnOff, bufferOffset;

        bank = ['a', 'b', 'c', 'd'].indexOf(drumStr.split($:)[0].asSymbol) + 1;
        start = drumStr.asString.split($:)[1].split($_)[0].asFloat;
        end = drumStr.asString.split($:)[1].split($_)[1];

        duration = if(end.isNil.not and: {(end.asFloat > start)}, {end.asFloat - start}, {nil});
        //[drumStr, duration].postln;

        Task({
            //turn of other buffers (all buffers if end < start, otherwise start buffer)
            //erase scheduled turn offs (all buffers if end < start, otherwise start buffer)
            banksToTurnOff = if(end.isNil.not and: {(end < start)}, {Set.newFrom((1..4)).remove(bank)}, {[]});
            banksToTurnOff.do({|i|
                maxPort.sendMsg("/sampLoop/" ++ i ++ "/playStop", "stop");
                if(heldHitTasks[i].isNil.not, {
                    heldHitTasks[i].stop;
                    heldHitTasks[i].free;
                    heldHitTasks[i] = nil;
                });
            });

            if(~max, {
                //play this buffer
                // 1/(beats/sec) * beats * ms/s
                bufferOffset = 1/(masterTempoClock.tempo/60) * start * 1000;
                maxPort.sendMsg("/sampLoop/" ++ bank ++ "/playStart", bufferOffset);
            });

            0.008.wait;

            //["SENTSAMP", ~sentCount, masterTempoClock.beats].postln;
            ~sentCount = ~sentCount+1;
            maxMidiOut.noteOn(0, bank, 60);

            if(~ableton, {
                Task({
                    midiOut.noteOn(0, 60, 60);
                    0.1.wait;
                    midiOut.noteOff(0, 60, 60);
                }).play;
            });

        }).play;

        //schedule turn off if needed
        if(duration.isNil.not, {
            heldHitTasks[bank] = Task({
                duration.wait;
                maxPort.sendMsg("/sampLoop/" ++ bank ++ "/playStop", "stop");
                ["SEND END", bank].postln;
            }, masterTempoClock).play;
        });
    });
};

)

~max=true
~ableton=false