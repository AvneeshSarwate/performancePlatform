(
var launchpadOut, launchPad, padOn, padMap, maxPort, updateTask, changes, turnOnPad, turnOffPad, keys, neighborCount, gameOfLife, lock, updateCounter, buttonMapToGrid, setButtonMapFromGrid, sendButtonMap, ccHandler, miniPadOn, savedMatricies, gameOfLife_BUTTON, videoSelectorButtons, videoSelectorColors, videoInd, liveNeighborMajority, videoSelectorFlashTask, getNewSelectorFlashTask, arrowButtons, gridRotate, up_BUTTON, down_BUTTON, left_BUTTON, right_BUTTON, lightUpButtonMap, swapMode, swapMode_BUTTON, swapCount, swapVidInds, padMapSwapInds;

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
maxPort = NetAddr("localhost", 5432);
savedMatricies = Dictionary.new;
gameOfLife_BUTTON = 89;
videoSelectorButtons = (10,20..80);
videoSelectorColors = [6, 13, 18, 67]
//red, orange, yellow, YG, green, turqoise, blue, purple
videoInd = 0;
videoSelectorFlashTask = Task({});
up_BUTTON = 91;
down_BUTTON = 92;
left_BUTTON = 93;
right_BUTTON = 94;
swapMode = false;
swapMode_BUTTON = 79;
swapCount = 0;
swapVidInds = List.new;

(0..100).do({|i| launchpadOut.noteOn(0, i, 0);});
(0..100).do({|i| padMap[i] = 0});

(0..3).do({|i| launchpadOut.noteOn(0, videoSelectorButtons[i], videoSelectorColors[i])});

keys = List.new;


changes = false;

turnOnPad = {|note, vidInd|
    padMap[note] = vidInd+1; //matrix is 1 indexed with 0 being no video
    launchpadOut.noteOn(0, note, videoSelectorColors[vidInd]);
};

turnOffPad = {|note|
    padMap[note] = 0;
    launchpadOut.noteOn(0, note, 0);
};

a = {|vel, note, chan, port|
    lock.wait;
    ["ON", note, padMap[note]];
    if(padMap[note] == (videoInd+1), {turnOffPad.(note)}, {turnOnPad.(note, videoInd)});
    changes = true;
    ~pMap = padMap;
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
        launchpadOut.control(0, note, if(~runGameOfLife, 3, 0));
    });
    if(videoSelectorButtons.includes(note) && (vel != 0), {
        if(swapMode,
            {
                swapVidInds.add(videoSelectorButtons.indexOf(note));
                if(swapVidInds.size == 2, {
                    lock.wait;
                    padMap = padMapSwapInds.(padMap, swapVidInds[0], swapVidInds[1]);
                    lightUpButtonMap.(padMap);
                    changes = true;
                    lock.signal;
                });
            },
            {
                videoInd = videoSelectorButtons.indexOf(note);
                ["VIDEO IND", videoInd].postln;
                videoSelectorFlashTask.stop;
                videoSelectorFlashTask.free;
                (0..3).do({|i| launchpadOut.noteOn(0, videoSelectorButtons[i], videoSelectorColors[i])});
                videoSelectorFlashTask = getNewSelectorFlashTask.();
                videoSelectorFlashTask.start;
            }
    )});

    if([up_BUTTON, down_BUTTON, left_BUTTON, right_BUTTON].includes(note) && (vel !=0), {
        lock.wait;
        if(note == up_BUTTON, {gridRotate.(padMap, 1, 0)});
        if(note == down_BUTTON, {gridRotate.(padMap, -1, 0)});
        if(note == left_BUTTON, {gridRotate.(padMap, 0, -1)});
        if(note == right_BUTTON, {gridRotate.(padMap, 0, 1)});
        lightUpButtonMap.(padMap);
        changes = true;
        lock.signal;
    });
    if(note == swapMode_BUTTON, {
        swapCount = 0;
        swapVidInds.clear;
        if(vel == 0, {swapMode = false}, {swapMode = true});
    });


};
ccHandler = MIDIFunc.cc(c, nil, nil, launchPad.uid);

padMapSwapInds = {|buttonMap, ind1, ind2|
    var oneTo2 = Set.new;
    var twoTo1 = Set.new;
    var newButtonMap = buttonMap.deepCopy;
    (8..1).do({|i|
        (1..8).do({|j|
            var note = (i*10)+j;
            if(buttonMap[note] == (ind1+1), {oneTo2.add(note)});
            if(buttonMap[note] == (ind2+1), {twoTo1.add(note)});
        });
    });
    ["SWAP NUMBERS", ind1, ind2, oneTo2.size, twoTo1.size].postln;
    oneTo2.do({|note| newButtonMap[note] = ind2+1});
    twoTo1.do({|note| newButtonMap[note] = ind1+1});
    newButtonMap;
};

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


//TODO - refactor to use this more and make all functions more pure
lightUpButtonMap = {|buttonMap|
    (8..1).do({|i|
        (1..8).do({|j|
            var note = (i*10)+j;
            var vidval = buttonMap[note];
            launchpadOut.noteOn(0, note, if(vidval == 0, 0, videoSelectorColors[vidval-1]));
        });
    });
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

~gameOfLifeStepDuration = 5;

updateTask = Task({
    {
        var calculateGameOfLifeStep;
        0.05.wait;
        updateCounter = updateCounter + 1;

        calculateGameOfLifeStep = ~runGameOfLife && ((updateCounter%~gameOfLifeStepDuration) == 0);

        if(changes || calculateGameOfLifeStep, {

            changes = false;

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
                var newX = (ix+m)%grid.size;
                var newY = (jy+n)%grid.size;
                if(~deadSet.includes(grid[newX][newY]).not, {
                    neighborCount[grid[newX][newY]] = neighborCount[grid[newX][newY]] + 1;
                    //[newX, newY, grid[ix][jy], neighborCount[grid[newX][newY]]].postln;
                });
            })
        });
    });
    //"COUNT DONE".postln;
    neighborCount.do({|val, ind| maxInd = if(val > maxInd, ind, maxInd) });
    maxInd;
};


~liveMaj = liveNeighborMajority;

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

~gOfL = gameOfLife;

buttonMapToGrid = {|buttonMap|
    var newG = List.fill(8, {List.fill(8, 0)});
    (8..1).do({|i|
        (1..8).do({|j|
            newG[i-1][j-1] = buttonMap[(i*10)+j];
        });
    });
    newG;
};

~mToG = buttonMapToGrid;

setButtonMapFromGrid = {|grid, buttonMap|
    (8..1).do({|i|
        (1..8).do({|j|
            var note = (i*10)+j;
            buttonMap[note] = grid[i-1][j-1];
            if(buttonMap[note]==0, {turnOffPad.(note)}, {turnOnPad.(note, buttonMap[note]-1)});
        });
    });
};

gridRotate = {|buttonMap, vertRotate, horRotate|
    var grid = buttonMapToGrid.(buttonMap);
    if(vertRotate != 0, {grid = grid.rotate(vertRotate)});
    if(horRotate != 0, {(0..7).do({|i| grid[i] = grid[i].rotate(horRotate)})});
    setButtonMapFromGrid.(grid, buttonMap);
};

)
(
~liveMaj2 = {|grid, ix, jy|
    var neighborCount = Array.fill(9, {0});
    var maxInd = -1;
    (-1..1).do({|m|
        (-1..1).do({|n|
            if((m.abs+n.abs) != 0, {
                var newX = (ix+m)%grid.size;
                var newY = (jy+n)%grid.size;
                if(~deadSet.includes(grid[newX][newY]).not, {
                    neighborCount[grid[newX][newY]] = neighborCount[grid[newX][newY]] + 1;
                    [newX, newY, grid[ix][jy], neighborCount[grid[newX][newY]]].postln;
                });
            })
        });
    });
    //"COUNT DONE".postln;
    neighborCount.do({|val, ind| maxInd = if(val > maxInd, ind, maxInd) });
    maxInd;
};
)

(
~oldG = ~mToG.(~pMap);
~newG = ~gOfL.(~mToG.(~pMap));
//.do({|l| l.postln})
~visP = {|gr| (7..0).do({|row| gr[row].postln})};
~visP.(~oldG);
"BREAK".postln;
~visP.(~newG);
)

~newG[6][1]
~liveMaj2.(~oldG, 7, 0)

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

