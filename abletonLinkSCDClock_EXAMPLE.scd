(
var tempo, adjustPhase, masterTempoClock, midiOut;


MIDIClient.init;
MIDIIn.connectAll;

midiOut = MIDIOut.newByName("IAC Driver", "Bus 2");
adjustPhase = false;

//msg[1] is the TEMPO in beats per MINUTE (tempoClock uses beats per SECOND)
OSCFunc({|msg, time, addr, recvPort|
    var drift, beat;

    //to prevent drift issues between Max-Link and the SCD clocks, I try to keep all
    //tempos an integer values
    var newTempo = msg[1].asInt;


    if(tempo.isNil, {tempo = newTempo});


    if(masterTempoClock.isNil, {
        masterTempoClock = TempoClock.new(tempo/60, 0);
        masterTempoClock.sched(0, {
            Task({
                "PLAY NOTE".postln;
                midiOut.noteOn(2, 40, 120);
                0.2.wait;
                midiOut.noteOff(2, 40, 0);
            }).play;
            1;
        });
    });


    /*While the Max-Link objects automatically handle phase compensation between themselves,
    a change in tempo can result in Max sending a metronome hit "out of phase" with the
    current supercollider clock. To compensate for this, we set the adjustPhase flag to true
    when the tempo changes, and then on the next Max-Link metronome hit, we round the beats value
    to bring it back into phase. We wait an extra beat to be sure that Max-Link is in phase
    before syncing the SC clock to it.
    */
    if(adjustPhase, {
        masterTempoClock.beats = masterTempoClock.beats.round;
        adjustPhase = false;
    });


    //if the drift between the link clock and the superocollider clock gets bad
    //we can manually compensate for it, but this is pretty rare
    beat = masterTempoClock.beats;
    drift = (beat.round - beat).abs;
    ["LINK BEAT", newTempo, masterTempoClock.beats, drift].postln;
    if(drift > 0.01, {
        "SHOULD NEVER BE THIS BAD".postln;
        masterTempoClock.beats = beat.round;
    });


	if(newTempo != tempo, {
		tempo = newTempo;
        masterTempoClock.tempo = tempo/60;
		adjustPhase = true;
	});

}, "/maxLink");


)


//use this to send a new tempo to the max link object
NetAddr.new("localhost", 5432).sendMsg("/setTempo", 180)