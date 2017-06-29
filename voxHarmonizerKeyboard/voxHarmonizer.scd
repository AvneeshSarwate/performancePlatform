(
var voiceInd;
var launchPad = MIDIClient.sources.select({|elem| (elem.name == "Standalone Port")
	&& (elem.device == "Launchpad Pro")})[0];
var oscOut = NetAddr.new("127.0.0.1", 5432);
var maxVoices = 5;
var onNotes = Set.new;

launchPad.noteOff({||vel, note, chan, port||
    //set pitch-diff of voice
    //turn on voice

}, nil, nil, launchPad.uid);

launchPad.noteOff({||vel, note, chan, port||
    //turn off voice

}, nil, nil, launchPad.uid);



)