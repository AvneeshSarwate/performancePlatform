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
var launchpadOut, launchPad, padOn, padMap, changedPads, maxPort, updateTask, changes, onPads, turnOnPad, turnOffPad, keys;

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

(0..100).do({|i| padMap[i] = 0});

keys = List.new;


changes = false;

turnOnPad = {|note|
    padMap[note] = 255;
    onPads.add(note);
    launchpadOut.noteOn(0, note, 17);
};
turnOffPad = {|note|
    padMap[note] = 0;
    onPads.remove(note);
    launchpadOut.noteOn(0, note, 0);
};

a = {|vel, note, chan, port|
    ["ON", note, padMap[note]];
    if(onPads.includes(note), {turnOffPad.(note)}, {turnOnPad.(note)});
    changedPads.add(note);
    changes = true;
};

updateTask = Task({
    {
        0.1.wait;
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

            msgList.clear;
            msgList.add("/buttons3");
            (8..1).do({|i|
                (1..8).do({|j|
                    msgList.add(padMap[(i*10)+j]);
                });
            });
            maxPort.sendRaw(msgList.asArray.asRawOSC);
            ["CHANGES", msgList].postln;
        });
    }.loop;
}).start;

padOn = MIDIFunc.noteOn(a, nil, nil, launchPad.uid);

)

[11, 21, 31, 41, 51, 61, 71, 81, 12,22,32,42,52,62,72,82, 13,23,33,43,53,63,73,83].do({|i| a.(nil, i, nil, nil)})