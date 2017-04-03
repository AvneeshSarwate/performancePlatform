(
var launchpadOut, maxOut, maxOut2, launchPad, padToInd, noiseRanges, noiseRangeButtons, lastPad, lastNoiseButton, notButton, notting, green_COLOR, red_COLOR, orange_COLOR, aToggleButton, vidAon, bToggleButton, vidBon;

MIDIClient.init;
MIDIIn.connectAll;

launchpadOut = MIDIOut.newByName("Launchpad Pro", "Standalone Port");
maxOut = MIDIOut.newByName("to Max 1", "to Max 1");
maxOut2 = MIDIOut.newByName("to Max 2", "to Max 2");
launchPad = MIDIClient.sources.select({|elem| (elem.name == "Standalone Port")
	&& (elem.device == "Launchpad Pro")})[0];
padToInd = {|padNum|
    ((8-(padNum/10).floor) * 8) + ((padNum%10)-1);
};

launchpadOut.latency = 0;
maxOut.latency = 0;

noiseRanges = [0, 2, 5, 10, 20, 30, 40, 50];
noiseRangeButtons = (19,29..89);
lastPad = 0;
lastNoiseButton = 0;
notButton = 98;
notting = false;
aToggleButton = 91;
bToggleButton = 92;
vidAon = true;
vidBon = true;

green_COLOR = 18;
red_COLOR = 5;
orange_COLOR = 96;


launchpadOut.noteOn(0, aToggleButton, orange_COLOR);
launchpadOut.noteOn(0, bToggleButton, orange_COLOR);

MIDIFunc.noteOn({|vel, note, chan, port|
    padToInd.(note).postln;
    maxOut.noteOn(0, padToInd.(note), vel);
    launchpadOut.noteOn(0, lastPad, 0);
    launchpadOut.noteOn(0, note, green_COLOR);
    lastPad = note;
}, nil, nil, launchPad.uid);



MIDIFunc.cc({|vel, note, chan, port|
    if(noiseRangeButtons.includes(note) && (vel != 0), {
        var ind = noiseRangeButtons.indexOf(note);
        maxOut.control(0, 1,  noiseRanges[ind]);
        launchpadOut.noteOn(0, lastNoiseButton, 0);
        launchpadOut.noteOn(0, note, red_COLOR);
        lastNoiseButton = note;
        ["CONTROL", noiseRanges[ind]].postln;
    });

    if((note == notButton) && (vel != 0), {
        notting = notting.not;
        launchpadOut.noteOn(0, note, if(notting, orange_COLOR, 0));
        maxOut2.noteOn(0, 100, 10)
    });
    if((note == aToggleButton) && (vel != 0), {
        vidAon = vidAon.not;
        launchpadOut.noteOn(0, note, if(vidAon, orange_COLOR, 0));
        maxOut2.noteOn(0, 50, 10)
    });
    if((note == bToggleButton) && (vel != 0), {
        vidBon = vidBon.not;
        launchpadOut.noteOn(0, note, if(vidBon, orange_COLOR, 0));
        maxOut2.noteOn(0, 51, 10)
    });
}, nil, nil, launchPad.uid);

)