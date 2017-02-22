(
NetAddr("localhost", 5432).sendMsg("/buttons", 11, 22, 33, 44, 55, 66, 77, 88)
)

(
var launchpadOut, launchPad, padOn, onPads, maxPort;

MIDIClient.init;
MIDIIn.connectAll;

launchpadOut = MIDIOut.newByName("Launchpad Pro", "Standalone Port");
launchpadOut.latency = 0;
launchPad = MIDIClient.sources.select({|elem| (elem.name == "Standalone Port")
	&& (elem.device == "Launchpad Pro")})[0];
onPads = Dictionary.new;
maxPort = NetAddr("localhost", 5432);


a = {|vel, note, chan, port|
    ["ON", note, onPads[note].isNil];
    if(onPads[note].isNil,
        {
            onPads[note] = true;
            maxPort.sendMsg("buttons", note, 255);
            launchpadOut.noteOn(0, note, 17);
        },
        {
            onPads[note] = nil;
            maxPort.sendMsg("/buttons", note, 0);
            launchpadOut.noteOn(0, note, 0);
        }
    );
};
padOn = MIDIFunc.noteOn(a, nil, nil, launchPad.uid);

)