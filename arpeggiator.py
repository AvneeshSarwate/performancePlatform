import PydalChanel
import OSC
import threading

class Arpeggiator:

	def __init__(self, midiChannel, pydalInstance, pattern, useIndependentHandler=False):
		self.onNotes = {}
		self.midiChannel = midiChannel
		self.pydalInstance = pydalInstance 
		self.channel = pydalInstance.newArpeggiatorChannel(midiChannel)
		self.pattern = pattern
		self.normalForwardingBehavior = True

		self.pydalInstance.superColliderServer.addMsgHandler("/broadcastNoteSelector-"+str(midiChannel), self.noteSelectorHanlder)

		if(useIndependentHandler):
			self.superColliderServer = OSC.OSCServer(('127.0.0.1', 34567))
			self.serverThread = threading.Thread(target=self.superColliderServer.serve_forever)
			self.serverThread.daemon = False
			self.serverThread.start()
			self.superColliderServer.addMsgHandler("/sendToArpeggiator", lambda addr, tags, stuff, source : self.handle(*stuff))

	def sendNoteDuration(self, duration):
		msg = OSC.OSCMessage()
		msg.setAddress("/noteDuration")
		msg.append(duration)
		self.pydalInstance.superColliderClient.send(msg)

	def noteSelectorHanlder(self, addr, tags, stuff, source):
		self.handle(stuff[0], stuff[1], stuff[2], stuff[3], None, True)

	def handle(self, chan, note, vel, onOff, launchpadKey, callFromModifiedBehavior=False):
		if self.normalForwardingBehavior or callFromModifiedBehavior:
			if onOff == "on":
				self.onNotes[note] = vel

				self.sendNoteUpdate(note, vel, onOff)

				if len(self.onNotes) == 1:
					self.channel.play(self.pattern)
			if onOff == "off" and note in self.onNotes:
				del self.onNotes[note]
				if len(self.onNotes) == 0:
					self.channel.stop()
				self.sendNoteUpdate(note, vel, onOff)

	def sendNoteUpdate(self, note, vel, onOff):
		msg = OSC.OSCMessage()
		msg.setAddress("/forwardNotes")
		msg.append(note)
		msg.append(vel)
		msg.append(onOff)
		msg.append(self.midiChannel)
		self.pydalInstance.superColliderClient.send(msg)
