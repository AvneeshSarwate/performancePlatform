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
		self.debug = False

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
		msg.append(self.midiChannel)
		self.pydalInstance.superColliderClient.send(msg)

	def noteSelectorHanlder(self, addr, tags, stuff, source):
		if len(stuff) == 4:
			self.handle(stuff[0], stuff[1], stuff[2], stuff[3], None, True)
		else:
			noteInfo = []
			swapChord = stuff[0]
			msgTrim = stuff[1:]
			print msgTrim, range(0, len(msgTrim), 4)
			oldNumOnNotes = len(self.onNotes)
			for i in range(0, len(msgTrim), 4):
				chan = msgTrim[i]
				note = msgTrim[i+1]
				vel = msgTrim[i+2]
				onOff = msgTrim[i+3]
				print "INDEX CHECK", i
				noteInfo.append((note, vel, onOff))

				if onOff == "on":
					self.onNotes[note] = vel

				if onOff == "off" and note in self.onNotes:
					del self.onNotes[note]
					
			print "POST NOTE UPDATE"
			if len(self.onNotes) == 0:
				self.channel.stop()
				if self.debug:
					print "arp off", self.onNotes, noteInfo

			self.sendChordUpdate(noteInfo)

			if len(self.onNotes) > 0:
				if not swapChord or oldNumOnNotes == 0:
					self.channel.play(self.pattern)
				if self.debug:
					print "arp on", self.onNotes, noteInfo


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

	# noteInfoList is [(note, vel, onOff)]
	def sendChordUpdate(self, noteInfoList):
		msg = OSC.OSCMessage()
		msg.setAddress("/forwardChord")
		msg.append(self.midiChannel)
		for i in noteInfoList:
			msg.append(i)
		self.pydalInstance.superColliderClient.send(msg)


	def sendNoteUpdate(self, note, vel, onOff):
		msg = OSC.OSCMessage()
		msg.setAddress("/forwardNotes")
		msg.append(note)
		msg.append(vel)
		msg.append(onOff)
		msg.append(self.midiChannel)
		self.pydalInstance.superColliderClient.send(msg)
