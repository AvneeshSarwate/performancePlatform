(
var masterTempoClock, broadcastOSCport, abletonLinkPort, tempo;

MIDIClient.init;
MIDIIn.connectAll;

broadcastOSCport = NetAddr("localhost", 57120);
abletonLinkPort = MIDIClient.sources.select({|elem| (elem.name == "Bus 6")
	&& (elem.device == "IAC Driver")})[0];


MIDIFunc.noteOn({|vel, note, chan, port|
	var newTempo = (note * 127) + vel;
	if(tempo.isNil, {tempo = newTempo});
	broadcastOSCport.sendMsg("/masterClockBeat", 60.0/tempo);
	["LINK BEAT", newTempo].postln;

	//should this go before or after the /masterClockBeat message? probably doesn't matter
	if(newTempo != tempo, {
		tempo = newTempo;
		broadcastOSCport.sendMsg("/masterClockTempo", 60.0/tempo, false); //don't worry about beat alignment for now
	});

}, nil, nil, abletonLinkPort.uid);
)