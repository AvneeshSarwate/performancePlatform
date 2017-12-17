(
var keyboardDict, oscOut, useArpeggiator, midiOut, keyboardKeys, heldKeys;

keyboardDict = Dictionary.new();
oscOut = NetAddr("localhost", 34567);
useArpeggiator = true;
midiOut = MIDIOut.newByName("IAC Driver", "Bus 2");
midiOut.latency = 0;
heldKeys = Set.new();

m = midiOut;

k = keyboardDict;
k["q"] = 60;
k["2"] = 61;
k["w"] = 62;
k["3"] = 63;
k["e"] = 64;
k["r"] = 65;
k["5"] = 66;
k["t"] = 67;
k["6"] = 68;
k["y"] = 69;
k["7"] = 70;
k["u"] = 71;
k["i"] = 72;
k["9"] = 71;
k["o"] = 74;
k["0"] = 73;
k["p"] = 76;

k["z"] = 45;
k["s"] = 46;
k["x"] = 47;
k["c"] = 48;
k["f"] = 49;
k["v"] = 50;
k["g"] = 51;
k["b"] = 52;
k["n"] = 53;
k["j"] = 54;
k["m"] = 55;
k["k"] = 56;
k[","] = 57;
k["l"] = 58;
k["."] = 59;

keyboardKeys = k.keys;


w = Window.new("I catch keystrokes");
w.view.keyDownAction = {|view, char, modifiers, unicode, keycode|
	if(char.asString == "`", {
		useArpeggiator = useArpeggiator.not;
	});

	if(keyboardKeys.includes(char.asString) && heldKeys.includes(char).not, {
		if(useArpeggiator,
			{
				oscOut.sendMsg("/sendToArpeggiator", 0, keyboardDict[char.asString], 64, "on");
				"ON SENT".postln;
			},
			{midiOut.noteOn(0, keyboardDict[char.asString], 64)}
		);
		heldKeys.add(char)
	});
};

w.view.keyUpAction = {|view, char, modifiers, unicode, keycode|
	if(keyboardKeys.includes(char.asString), {
		if(useArpeggiator,
			{oscOut.sendMsg("/sendToArpeggiator", 0, keyboardDict[char.asString], 64, "off")},
			{midiOut.noteOff(0, keyboardDict[char.asString], 64)}
		);
	});
	heldKeys.remove(char);
};
w.front;
)

m.allNotesOff(0);

m.noteOn(0, 60, 60);
m.noteOff(0, 60, 60);




// use mouse as xy pad for 2 arbitrary midi ccs
s.boot

(
SynthDef(\mousedemo, {
var mx,my, impulse;

mx= MouseX.kr(0.0,1.0);
my= MouseY.kr(0.0,1.0);

impulse= Impulse.kr(15); //update at 15Hz = haptic rate

SendTrig.kr(impulse, 100, mx);
SendTrig.kr(impulse, 101, my);

}).play;
)



(
var mx, my;

OSCresponder(s.addr,'/tr',{ arg time,responder,msg;
var value;

//Post << msg << nl;
value= msg[3];

switch (msg[2],
100, {mx= value;},
101,{my=value;});
}).add;

{inf.do{[\mx, mx, \my, my].postln; 0.5.wait;}}.fork;

)