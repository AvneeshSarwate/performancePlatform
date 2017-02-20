(
var midiOut, channelMap, startWaveHandler, stopWaveHandler, startWave, stopWave, masterTempoClock, maxOSCport;
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


midiOut = MIDIOut.newByName("IAC Driver", "Bus 3");
midiOut.latency = 0;

maxOSCport = NetAddr("localhost", 5432);

//TODO: move variable instations to near the functions that use them
OSCFunc({|msg, time, addr, recvPort|
	//msg[1] is the new BEAT DURATION (not tempo)
	masterTempoClock = TempoClock.new(1/msg[1], 0);
}, "/masterClockBeat").oneShot;

//cc ind -> waveTask
channelMap = Dictionary.new;
~chanDebugMap = Dictionary.new;
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
                    maxOSCport.sendMsg(ccIndOrWaveAddr.asString, func.(masterTempoClock.beats))
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
    ~chanDebugMap[msg[1]] = [createCalcFunc.(msg[2].asString), msg[2].asString];
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