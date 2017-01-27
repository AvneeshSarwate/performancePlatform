(
var midiOut, channelMap, startWaveHandler, stopWaveHandler, startWave, stopWave, masterTempoClock;
var sinwav = {|f,p,a,s, time| (sin((pi*f*time)+p)*a)+s};
var coswav = {|f,p,a,s, time| (cos((pi*f*time)+p)*a)+s};

var sqr = {|time| var tm = time%2; if(tm<1, 1, -1)};
var sqrwav = {|f,p,a,s, time| (sqr.((f*time)+p)*a)+s};

var saw = {|time| var tm = time%2; tm-1};
var sawwav = {|f,p,a,s, time| (saw.((f*time)+p)*a)+s};

var tri = {|time| var tm = time%2; case {tm<0.5} {1-(2*tm)} {tm<1.5} {2-(2*tm)} {tm>=1.5} {2*tm-4}};
var triwav = {|f,p,a,s, time| (tri.((f*time)+p)*a)+s};

var calcStr = "triwav.(1,0,1,triwav.(3,0,sinwav.(sawwav.(5,0,1,0,time),0,0.333333333333,0.0,time),0.0,time),time)";
var createCalcFunc = {|calcString|
    var prepFunc = ("{|sinwav, coswav, sqrwav, sawwav, triwav| {|time|" + calcStr + "}};").interpret;
    prepFunc.(sinwav, coswav, sqrwav, sawwav, triwav);
};

var func = createCalcFunc.(calcStr);
func.(1);


midiOut = MIDIOut.newByName("IAC Driver", "Bus 3");
midiOut.latency = 0;

//TODO: move variable instations to near the functions that use them
OSCFunc({|msg, time, addr, recvPort|
	//msg[1] is the new BEAT DURATION (not tempo)
	masterTempoClock = TempoClock.new(1/msg[1], 0);
}, "/masterClockBeat").oneShot;

//cc ind -> waveTask
channelMap = Dictionary.new;

//msg[1] is cc ind, msg[2] is calcString
startWave = {|msg, time, addr, recvPort|
    var waveTask = Task({
        var func = createCalcFunc.(msg[2].asString);
        var ccInd = msg[1].asInt;
        {
            var rawVal = (func.(masterTempoClock.beats) + 64).round;
            var val = max(min(127, rawVal), 0);
            midiOut.control(0, ccInd, val);
            0.02.wait;
        }
    });
    waveTask.start;
    if(channelMap[msg[1]].isNil.not, {
        channelMap[msg[1]].stop;
        channelMap[msg[1]].free;
    });
    channelMap[msg[1]] = waveTask;
};
startWaveHandler = OSCFunc(startWave, "/startWave");

stopWaveHandler = {|msg, time, addr, recvPort|
    if(channelMap[msg[1]].isNil.not, {
        channelMap[msg[1]].stop;
        channelMap[msg[1]].free;
    });
    channelMap[msg[1]] = nil;
};
stopWaveHandler = OSCFunc(stopWave, "/stopWave");

)


(
var tri = {|time| var tm = time%2; case {tm<0.5} {1-(2*tm)} {tm<1.5} {2-(2*tm)} {tm>=1.5} {2*tm-4}};
var triwav = "{|tri, f,p,a,s, time| (tri.((f*time)+p)*a)+s}".interpret;
triwav.(tri, 1, 0, 1, 0, 0.25)

)

(
d = Dictionary.new;
d[5]
)