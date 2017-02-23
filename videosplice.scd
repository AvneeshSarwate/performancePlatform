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

~runGameOfLife = false

(
var launchpadOut, launchPad, padOn, padMap, changedPads, maxPort, updateTask, changes, onPads, turnOnPad, turnOffPad, keys, neighborCount, gameOfLife, lock, updateCounter, buttonMapToGrid, setButtonMapFromGrid, sendButtonMap;

MIDIClient.init;
MIDIIn.connectAll;

~runGameOfLife = true;

lock = Semaphore(1);
updateCounter = 0;

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
    lock.wait;
    ["ON", note, padMap[note]];
    if(onPads.includes(note), {turnOffPad.(note)}, {turnOnPad.(note)});
    changedPads.add(note);
    changes = true;
    lock.signal;
};
padOn = MIDIFunc.noteOn(a, nil, nil, launchPad.uid);


sendButtonMap = {
    var msgList = List.new;
    msgList.add("/buttons3");
    (8..1).do({|i|
        (1..8).do({|j|
            msgList.add(padMap[(i*10)+j]);
        });
    });
    ["CHANGES", msgList].postln;
    maxPort.sendRaw(msgList.asArray.asRawOSC);
};

updateTask = Task({
    {
        var calculateGameOfLifeStep;
        0.1.wait;
        updateCounter = updateCounter + 1;

        calculateGameOfLifeStep = ~runGameOfLife && ((updateCounter%10) == 0);

        if(changes || calculateGameOfLifeStep, {

            changes = false;
            changedPads.clear;

            lock.wait;
            //modify padMap via gameOfLife here
            if(calculateGameOfLifeStep, {
                var oldGrid, newGrid;
                oldGrid = buttonMapToGrid.(padMap);
                "OLD GRID".postln;
                newGrid = gameOfLife.(oldGrid);
                "NEW GRID".postln;
                setButtonMapFromGrid.(newGrid, padMap);
                "MAP SET".postln;
                updateCounter = 0;

            });

            sendButtonMap.();
            lock.signal;
        });
    }.loop;
}).start;

neighborCount = {|grid, ix, jy|
    var count = 0;
    "COUNT START".postln;
    (-1..1).do({|m|
        (-1..1).do({|n|
            if((m.abs+n.abs) != 0, {
               if(grid[(ix+m)%grid.size][(jy+n)%grid.size] != 0, {
                    count = count + 1;
                });
            })
        });
    });
    "COUNT DONE".postln;
    count;
};

gameOfLife = {|oldG|
    var newG = List.fill(8, {List.fill(8, 0)});
    (0..7).do({|i|
        (0..7).do({|j|
            var c = neighborCount.(oldG, i, j);
            if((c < 2) || (c > 3), {newG[i][j] = 0});
            if([2,3].includes(c), {newG[i][j] = oldG[i][j]});
            if(c == 3, {newG[i][j] = 255});
        });
    });
    newG;
};

buttonMapToGrid = {|buttonMap|
    var newG = List.fill(8, {List.fill(8, 0)});
    (8..1).do({|i|
        (1..8).do({|j|
            newG[i-1][j-1] = buttonMap[(i*10)+j];
        });
    });
    newG;
};

setButtonMapFromGrid = {|grid, buttonMap|
    (8..1).do({|i|
        (1..8).do({|j|
            var note = (i*10)+j;
            buttonMap[note] = grid[i-1][j-1];
            if(buttonMap[note]==0, {turnOffPad.(note)}, {turnOnPad.(note)});
        });
    });
};

)

