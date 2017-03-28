//20 points - 8 for arms, 8 for center-and-left-leg, 4 for right-leg



(
//skeletonFrames
~frames = List.new;

OSCFunc({|msg, time, addr, recvPort|

    //map grid coordinates to processing draw coordinates

    //add list to skeleton frame



}, "/gridSkeleton")

//calculateInterolation
~calcInterp = {|frame1, frame2, interpolation|
    var newFrame = List.new;
    (0..(frame1.size-1)).do({|i|
        var diff = frame2[i] - frame1[i];
        newFrame.add(frame1[i] + (diff*interpolation))
    });
    newFrame
}

~sendFrames = Task({
    var nFr = {~skeletonFrames.size};
    var interpSteps = 100; //number of interpolation steps
    var frameTime = 1/60;
    var interpInd = 0; //interpolation index
    var frameInd = 0;

    var frameToSend = ~calcInterp.(~frames[frameInd], ~frames[frameInd+1%nFr.()], interpInd/interpSteps);

    interpInd = interpInd+1%interpSteps;
    if(interpInd == 0, {frameInd = frameInd+1%nFr.()});

    frameTime.wait;
});


)

