//20 points - 8 for arms, 8 for center-and-left-leg, 4 for right-leg



(
~processingPort = NetAddr("localhost", 12000);

//skeletonFrames
~frames = List.new;

~recieveFrame = {|msg, time, addr, recvPort|
    var fr = msg[1..40];
    ~frames.add(fr);
    msg.postln;
};

OSCFunc(~recieveFrame, "/gridSkeleton");

//calculateInterolation
~calcInterp = {|frame1, frame2, interpolation|
    var newFrame = List.new;
    (0..(frame1.size-1)).do({|i|
        var diff = frame2[i] - frame1[i];
        newFrame.add(frame1[i] + (diff*interpolation))
    });
    newFrame
};

~sendFrames = Task({
    var nFr = {~frames.size};
    var interpSteps = 20; //number of interpolation steps
    var frameTime = 1/10;
    var interpInd = 0; //interpolation index
    var frameInd = 0;

    {
        if(~frames.size > 0, {
            var frameToSend = ~calcInterp.(~frames[frameInd], ~frames[frameInd+1%nFr.()], interpInd/interpSteps);

            interpInd = interpInd+1%interpSteps;
            if(interpInd == 0, {frameInd = frameInd+1%nFr.()});
            frameToSend.postln;
            (["/skeletonFrame"]++frameToSend).asArray.asRawOSC.postln;
            ~processingPort.sendRaw((["/skeletonFrame"]++frameToSend).asArray.asRawOSC);
        });
        frameTime.wait;
    }.loop;
});

~sendFrames.start;

"ALL STARTED".postln;
)


~sendFrames.stop;