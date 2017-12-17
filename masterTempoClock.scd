(
var masterTempoClock, broadcastOSCport;

MIDIClient.init;
MIDIIn.connectAll;
~lightIndexes = List.new;
~lightIndex = nil;
~lock = Semaphore(1);
~cycling = true;
~getLaunchpad = {|launchpadInd|
    var ind = MIDIClient.destinations.collect({|elem, ind| if(((elem.name == "Standalone Port") && (elem.device == "Launchpad Pro")), ind, nil)}).select({|elem| elem.isNil.not})[launchpadInd];
    MIDIOut.new(ind);
};
masterTempoClock = TempoClock.new(2);
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