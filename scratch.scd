OSCFunc.trace

(
var maxPort = NetAddr("127.0.0.l", 5432);
OSCFunc.newMatching({|msg, time, addr, recvPort|
    "MATCH".postln;
}, "/rotate");

OSCFunc.new({|msg, time, addr, recvPort|
    msg.postln;
    maxPort.sendRaw(msg.asRawOSC);
}, "/rotate/1");

)