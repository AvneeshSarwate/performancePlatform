(
var broadcastOSCport, tempo, maxPort;

MIDIClient.init;
MIDIIn.connectAll;
~lightIndexes = List.new;
~lightIndex = nil;

broadcastOSCport = NetAddr("localhost", 57120);
maxPort = NetAddr("localhost", 5432);

//msg[1] is the new TEMPO
OSCFunc({|msg, time, addr, recvPort|
    var newTempo = msg[1].asFloat;
	if(tempo.isNil, {tempo = newTempo});
	broadcastOSCport.sendMsg("/masterClockBeat", 60.0/tempo);
	//["LINK BEAT", newTempo].postln;

	//should this go before or after the /masterClockBeat message? probably doesn't matter
	if(newTempo != tempo, {
		tempo = newTempo;
		broadcastOSCport.sendMsg("/masterClockTempo", 60.0/tempo, false); //don't worry about beat alignment for now
	});
}, "/maxLink");


//msg[1] is the new BEAT DURATION (not tempo)
OSCFunc({|msg, time, addr, recvPort|
    var newTempo = 60.0/msg[1];
    ["new tempo pre max link", newTempo].postln;
	maxPort.sendMsg("/tempoUpdateRequest", newTempo)
}, "/uploadTempo");

)