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
var launchpadOut, launchPad, padOn, padMap, changedPads, maxPort, updateTask, changes, onPads, turnOnPad, turnOffPad, keys, neighborCount, gameOfLife, lock, updateCounter, buttonMapToGrid, setButtonMapFromGrid, sendButtonMap, ccHandler, miniPadOn, savedMatricies, gameOfLife_BUTTON, videoSelectorButtons, videoSelectorColors, videoInd, liveNeighborMajority, videoSelectorFlashTask, getNewSelectorFlashTask;

MIDIClient.init;
MIDIIn.connectAll;

~runGameOfLife = false;
~deadSet = [0];

lock = Semaphore(1);
updateCounter = 0;

launchpadOut =  MIDIOut.newByName("Launchpad Pro", "Standalone Port"); //MIDIOut.new(11); //
launchpadOut.latency = 0;
launchPad = MIDIClient.sources.select({|elem| (elem.name == "Standalone Port")
	&& (elem.device == "Launchpad Pro")})[0];
padMap = Dictionary.new;
changedPads = Set.new;
onPads = Set.new;
maxPort = NetAddr("localhost", 5432);
savedMatricies = Dictionary.new;
gameOfLife_BUTTON = 89;
videoSelectorButtons = (10,20..80);
videoSelectorColors = [6, 9, 13, 109, 18, 32, 67, 116];
//red, orange, yellow, YG, green, turqoise, blue, purple
videoInd = 0;
videoSelectorFlashTask = Task({});

(0..100).do({|i| launchpadOut.noteOn(0, i, 0);});
(0..100).do({|i| padMap[i] = 0});

(0..7).do({|i| launchpadOut.noteOn(0, videoSelectorButtons[i], videoSelectorColors[i])});

keys = List.new;


changes = false;

turnOnPad = {|note, vidInd|
    padMap[note] = vidInd+1; //matrix is 1 indexed with 0 being no video
    onPads.add(note);
    launchpadOut.noteOn(0, note, videoSelectorColors[vidInd]);
};

turnOffPad = {|note|
    padMap[note] = 0;
    onPads.remove(note);
    launchpadOut.noteOn(0, note, 0);
};

a = {|vel, note, chan, port|
    lock.wait;
    ["ON", note, padMap[note]];
    if(padMap[note] == (videoInd+1), {turnOffPad.(note)}, {turnOnPad.(note, videoInd)});
    changedPads.add(note);
    changes = true;
    lock.signal;
};

padOn = MIDIFunc.noteOn(a, nil, nil, launchPad.uid);

getNewSelectorFlashTask = {
    Task({
        var on = false;
        var selectorNote = videoSelectorButtons[videoInd];
        {
            0.24.wait;
            launchpadOut.noteOn(0, selectorNote, if(on, videoSelectorColors[videoInd], 0));
            on = on.not;
        }.loop;
    });
};

videoSelectorFlashTask = getNewSelectorFlashTask.();
videoSelectorFlashTask.start;

c = {|vel, note, chan, port|
    if((note == gameOfLife_BUTTON) && (vel != 0), {
       ~runGameOfLife = ~runGameOfLife.not;
        launchpadOut.control(0, note, if(~runGameOfLife, 79, 0));
    });
    if(videoSelectorButtons.includes(note) && (vel != 0), {
        videoInd = videoSelectorButtons.indexOf(note);
        ["VIDEO IND", videoInd].postln;
        videoSelectorFlashTask.stop;
        videoSelectorFlashTask.free;
        (0..7).do({|i| launchpadOut.noteOn(0, videoSelectorButtons[i], videoSelectorColors[i])});
        videoSelectorFlashTask = getNewSelectorFlashTask.();
        videoSelectorFlashTask.start;
    });
};
ccHandler = MIDIFunc.cc(c, nil, nil, launchPad.uid);

sendButtonMap = {
    var msgList = List.new;
    msgList.add("/filterMatrix88");
    (8..1).do({|i|
        (1..8).do({|j|
            msgList.add(padMap[(i*10)+j]);
        });
    });
    ["CHANGES", msgList].postln;
    maxPort.sendRaw(msgList.asArray.asRawOSC);
};

//msg[1] saved matrix index
OSCFunc({|msg, time, addr, recvPort|
    savedMatricies[msg[1]] = padMap.deepCopy;
    "SAVED".postln;
}, "/saveMatrix");

//msg[1] saved matrix index
OSCFunc({|msg, time, addr, recvPort|
    lock.wait;
    padMap = savedMatricies[msg[1]].deepCopy;
    (8..1).do({|i|
        (1..8).do({|j|
            var note = (i*10)+j;
            if(padMap[note]==0, {turnOffPad.(note)}, {turnOnPad.(note, padMap[note]-1)});
        });
    });
    changes = true;
    "PLAYED".postln;
    lock.signal;
}, "/playMatrix");

updateTask = Task({
    {
        var calculateGameOfLifeStep;
        0.05.wait;
        updateCounter = updateCounter + 1;

        calculateGameOfLifeStep = ~runGameOfLife && ((updateCounter%3) == 0);

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
    (-1..1).do({|m|
        (-1..1).do({|n|
            if((m.abs+n.abs) != 0, {
                if(~deadSet.includes(grid[(ix+m)%grid.size][(jy+n)%grid.size]).not, {
                    count = count + 1;
                });
            })
        });
    });
    //"COUNT DONE".postln;
    count;
};

liveNeighborMajority = {|grid, ix, jy|
    var neighborCount = Array.fill(9, {0});
    var maxInd = -1;
    (-1..1).do({|m|
        (-1..1).do({|n|
            if((m.abs+n.abs) != 0, {
                if(~deadSet.includes(grid[(ix+m)%grid.size][(jy+n)%grid.size]).not, {
                    neighborCount[grid[ix][jy]] = neighborCount[grid[ix][jy]] + 1;
                });
            })
        });
    });
    //"COUNT DONE".postln;
    neighborCount.do({|val, ind| maxInd = if(val > maxInd, ind, maxInd) });
    maxInd;
};

gameOfLife = {|oldG|
    var newG = List.fill(8, {List.fill(8, 0)});
    (0..7).do({|i|
        (0..7).do({|j|
            var c = neighborCount.(oldG, i, j);
            if((c < 2) || (c > 4), {newG[i][j] = 0});
            if([2,3].includes(c), {newG[i][j] = oldG[i][j]});
            if(c == 3, {newG[i][j] = liveNeighborMajority.(oldG, i, j)});
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

