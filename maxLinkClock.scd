(
var masterTempoClock, broadcastOSCport, tempo;

MIDIClient.init;
MIDIIn.connectAll;

masterTempoClock = TempoClock.new(1);
broadcastOSCport = NetAddr("localhost", 57120);

masterTempoClock.sched(0, {broadcastOSCport.sendMsg("/masterClockBeat", masterTempoClock.beatDur); 1});

//msg[1] is the new tempo
OSCFunc({|msg, time, addr, recvPort|
    var newTempo = msg[1].asFloat;
	if(tempo.isNil, {tempo = newTempo});
	broadcastOSCport.sendMsg("/masterClockBeat", 60.0/tempo);
	//["max LINK BEAT", newTempo].postln;

	//should this go before or after the /masterClockBeat message? probably doesn't matter
	if(newTempo != tempo, {
		tempo = newTempo;
		broadcastOSCport.sendMsg("/masterClockTempo", 60.0/tempo, false); //don't worry about beat alignment for now
	});
}, "/maxLink");
)