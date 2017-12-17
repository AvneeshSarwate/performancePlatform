(
var midiOut, channelMap, startWaveHandler, stopWaveHandler, startWave, stopWave, masterTempoClock, maxOSCport, scPort;
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


var plotFunc = {|calcFunc, start, end, calcFuncStr|
    var waveStepFrac = 0.02;
    var vals = (start, (start+waveStepFrac) .. end).collect({|i| calcFunc.(i)});
    ~debugf = calcFunc;
    AppClock.sched(0.1, {vals.plot});
    ["SENT WAVE DATA", vals.maxItem, vals.minItem, calcFuncStr, vals].postln;
};


// msg[1] is calc string
// msg[2] is start of plot range
// msg[3] is end of plot range
OSCFunc.new({|msg, time, addr, recvPort|
    plotFunc.(createCalcFunc.(msg[1].asString), msg[2].asInt, msg[3].asInt, msg[1].asString);
}, "/plotWave");



midiOut = MIDIOut.newByName("IAC Driver", "Bus 3");
midiOut.latency = 0;

maxOSCport = NetAddr("localhost", 5432);
scPort = NetAddr("127.0.0.1", 57120);

//TODO: move variable instations to near the functions that use them
OSCFunc({|msg, time, addr, recvPort|
	//msg[1] is the new BEAT DURATION (not tempo)
	masterTempoClock = TempoClock.new(1/msg[1], 0);
    Task({
    {
        maxOSCport.sendMsg("/scrollUpdate", 0);
        0.1.wait; //this is hardcoded into scrollLine.js in drawCurve.maxpat
    }.loop;
}, masterTempoClock).start;
}, "/masterClockBeat").oneShot;

//cc ind -> waveTask
channelMap = Dictionary.new;
~chanDebugMap = Dictionary.new;
//msg[1] is cc ind and/or waveKey, msg[2] is calcString, msg[3] is "OSC" or "midi",
//msg[4] is "max" or "sc" port, msg[5] is OSC addr, msg [6...] is meta info for OSC waves
startWave = {|msg, time, addr, recvPort|
    var waveTask = Task({
        var func = createCalcFunc.(msg[2].asString);
        var ccIndOrWaveAddr = msg[1];
        var oscAddr = msg[5].asString;
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
                    var port = if(msg[4].asSymbol == 'max', maxOSCport, scPort);
                    //[oscAddr, func.(masterTempoClock.beats)].postln;
                    port.sendRaw(([oscAddr, func.(masterTempoClock.beats)]++[msg[6]]).asArray.asRawOSC)
                }
            );
            0.02.wait;
        }.loop;
    }, masterTempoClock);
    var waveBufferTask = Task({
        var func = createCalcFunc.(msg[2].asString);
        {
            var waveBuffer = (0,0.025..16).collect({|time| (func.(time)+64}); //step size is hardcoded both here and drawCurve.js/maxpat
            ["VALUES", waveBuffer].postln;
            maxOSCport.sendRaw((["/curveValues"]++waveBuffer).asArray.asRawOSC);
            16.wait
        }.loop;

    }, masterTempoClock);
    msg.postln;
    waveTask.start;
    waveBufferTask.start;
    if(channelMap[msg[1]].isNil.not, {
        channelMap[msg[1]][0].stop;
        channelMap[msg[1]][0].free;
        channelMap[msg[1]][1].stop;
        channelMap[msg[1]][1].free;
    });
    channelMap[msg[1]] = [waveTask, waveBufferTask];
    ~chanDebugMap[msg[1]] = [createCalcFunc.(msg[2].asString), msg[2].asString];
};
startWaveHandler = OSCFunc(startWave, "/startWave");

//msg[1] is cc ind OR waveOSCAddress
stopWave = {|msg, time, addr, recvPort|
    msg.postln;
    if(channelMap[msg[1]].isNil.not, {
        channelMap[msg[1]][0].stop;
        channelMap[msg[1]][0].free;
        channelMap[msg[1]][1].stop;
        channelMap[msg[1]][1].free;
    });
    channelMap[msg[1]] = nil;
};
stopWaveHandler = OSCFunc(stopWave, "/stopWave");


)


(
v = 81;
~debugf = ~chanDebugMap[v][0];
~chanDebugMap[v][1].postln;
(0..500).collect({|i| ~debugf.(i*0.02)}).plot;
k = 1000;
(k..(k+500)).collect({|i| ~debugf.(i*0.02)}).plot;
)


(
var midiOut, channelMap, startWaveHandler, stopWaveHandler, startWave, stopWave, masterTempoClock;
var sinwav = {|fr,ph,am,sh, time| (sin((pi*fr*time)+ph)*am)+sh};
var coswav = {|fr,ph,am,sh, time| (cos((pi*fr*time)+ph)*am)+sh};

var sqr = {|time| var tm = time%2; if(tm<1, 1, -1)};
var sqrwav = {|fr,ph,am,sh, time| (sqr.((fr*time)+ph)*am)+sh};

var saw = {|time| var tm = time%2; tm-1};
var sawwav = {|fr,ph,am,sh, time| (saw.((fr*time)+ph)*am)+sh};

var tri = {|time| var tm = time%2; case {tm<0.5} {2*tm} {tm<1.5} {2-(2*tm)} {tm>=1.5} {2*tm-4}};
var triwav = {|fr,ph,am,sh, time| (tri.((fr*time)+ph)*am)+sh};

var calcStr = ~chanDebugMap[v][1];

var createCalcFunc = {|calcString|
    var prepFunc = ("{|sinwav, coswav, sqrwav, sawwav, triwav| {|time|" + calcString + "}};").interpret;
    prepFunc.(sinwav, coswav, sqrwav, sawwav, triwav);
};

var func = createCalcFunc.(calcStr);
var early = (0..500).collect({|i| func.(i*0.02)});
var late = (3000..3500).collect({|i| func.(i*0.02)});
[early == late, early.mean, late.mean, early.maxItem, late.maxItem, early.minItem, late.minItem].postln;
early.collect({|i| func.(i*0.02)}).plot;
late.collect({|i| func.(i*0.02)}).plot;
func.(0.5);

)

(
d = Dictionary.new;
d[5]
)

{ PinkNoise.ar(0.2) + SinOsc.ar(440, 0, 0.2) + Saw.ar(660, 0.2) }.scope;