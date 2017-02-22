(
var netAddr = NetAddr("localhost", 5432);
Task({
    var switch = 0.1;
    var diff = 0;
    (0..10).do({
        netAddr.sendMsg("/matrixswitch0", 1);
        (switch-diff).wait;
        netAddr.sendMsg("/matrixswitch1", 1);
        (switch+diff).wait;
        "yo".postln;
    });
}).play

)


(
NetAddr("localhost", 5432).sendMsg("/matrixswitch0", 1);
)

(
var launchpadOut, launchPad, padOn, padMap, changedPads, maxPort, updateTask, changes, onPads;

MIDIClient.init;
MIDIIn.connectAll;

launchpadOut = MIDIOut.newByName("Launchpad Pro", "Standalone Port");
launchpadOut.latency = 0;
launchPad = MIDIClient.sources.select({|elem| (elem.name == "Standalone Port")
	&& (elem.device == "Launchpad Pro")})[0];
padMap = Dictionary.new;
changedPads = Set.new;
onPads = Set.new;
maxPort = NetAddr("localhost", 5432);
(0..100).do({|i| launchpadOut.noteOn(0, i, 0);});

changes = false;

a = {|vel, note, chan, port|
    ["ON", note, padMap[note]];
    if(onPads.includes(note),
        {
            padMap[note] = 0;
            onPads.remove(note);
            launchpadOut.noteOn(0, note, 0);
        },
        {
            padMap[note] = 255;
            onPads.add(note);
            launchpadOut.noteOn(0, note, 17);
        }
    );
    changedPads.add(note);
    changes = true;
};

updateTask = Task({
    {
        0.05.wait;
        if(changes, {
            var msgList = List.new;
            msgList.add("/buttons2");

            changedPads.do({|key|
                msgList.add(key);
                msgList.add(padMap[key]);
            });

            maxPort.sendRaw(msgList.asArray.asRawOSC);
            changes = false;
            changedPads.clear;
            ["CHANGES", msgList].postln;
        });
    }.loop;
}).start;

padOn = MIDIFunc.noteOn(a, nil, nil, launchPad.uid);

)