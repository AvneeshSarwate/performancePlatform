(
var masterTempoClock, broadcastOSCport;

MIDIClient.init;
MIDIIn.connectAll;
~lightIndexes = List.new;
~lightIndex = nil;
~lock = Semaphore(1);
~cycling = true;

masterTempoClock = TempoClock.new(1);
broadcastOSCport = NetAddr("localhost", 57120);

masterTempoClock.sched(0, {broadcastOSCport.sendMsg("/masterClockBeat", masterTempoClock.beatDur); 1});

//msg[1] is the new BEAT DURATION (not tempo)
//msg[2] is whether the beat is being realigned
OSCFunc({|msg, time, addr, recvPort|
	masterTempoClock.tempo = 1/msg[1].asFloat;
	broadcastOSCport.sendMsg("/masterClockTempo", msg[1].asFloat, msg[2].asBoolean)
}, "/uploadTempo");
)

~lightIndex=0