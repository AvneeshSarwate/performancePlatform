(var pedal, pedalNoteOnFunc, pythonOSCport;

pedal = MIDIClient.sources.select({|elem| (elem.device == "FBV Express Mk II")
	&& (elem.name == "Port 1")})[0];
pythonOSCport = NetAddr("localhost", 13371);


pedalNoteOnFunc = {|vel, pedalNote, chan, port|
	if((pedalNote == 16) && (vel == 127), {
        pythonOSCport.sendMsg("/pedalButton");
        "PEDAL BUTTON".postln;
	});
};
MIDIFunc.cc(pedalNoteOnFunc, nil, nil, pedal.uid);

)