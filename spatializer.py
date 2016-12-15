import copy
import OSC
import heapq

class Spatializer:

	def __init__(self, root, noteSets):
		self.root = root
		self.noteSets = noteSets
		self.newNoteSets = map(lambda noteSet: map(lambda degree: (root+degree)%12, noteSet), noteSets)
		self.spatialize = True
		self.client = OSC.OSCClient()
		self.client.connect( ('127.0.0.1', 57120) )
		self.sustaining = True
		self.onNotes = set()

		#NOTE: using channelSeparation and spatialization on same instrument will cause undefined behavior
		self.separateChannels = False  
		self.noteToChanMap = {}
		#talking all extra bass channels and all drum channels except 1, on top of 4 "inst 2" channels
		self.openChannels = [1, 2, 5, 6, 7, 9, 10, 11, 13, 14, 15]  

	def handle(self, channel, note, vel, keyOnOff):
		onOff = self.resolveOnOff(note, keyOnOff)
		if onOff is None:
			return
		newChannel = self.getChan(note, channel, onOff)
		msg = OSC.OSCMessage()
		self.sendNote(newChannel, note, vel, onOff)

	def heldNotesOff(self, chan):
		for note in self.onNotes:
			self.sendNote(chan, note, 0, "off")
			if note in self.noteToChanMap:
				self.sendNote(self.noteToChanMap[note], note, 0, "off")
				del self.noteToChanMap[note]

	def sendNote(self, channel, note, vel, onOff):
		msg = OSC.OSCMessage()
		msg.setAddress("/spatializePlay")
		msg.append(channel)
		msg.append(note)
		msg.append(vel)
		msg.append(onOff)
		self.client.send(msg)

	def resolveOnOff(self, note, keyOnOff):
		if self.sustaining:
			if keyOnOff == "on":
				if note in self.onNotes:
					self.onNotes.remove(note)
					return "off"
				else:
					self.onNotes.add(note)
					return "on"
		else:
			if not note in self.onNotes:
				return keyOnOff
		
	def getChan(self, note, channel, onOff):
		if self.separateChannels:
			if onOff == "on":
				chan = heapq.heappop(self.openChannels)
				self.noteToChanMap[note] = chan
				return chan
			else:
				chan = self.noteToChanMap[note]
				heapq.heappush(self.openChannels, chan)
				del self.noteToChanMap[note]
				return chan
		if self.spatialize:
			spatialChan = 0
			for i in range(len(self.newNoteSets)):
				if note % 12 in self.newNoteSets[i]:
					spatialChan = i+1
			return channel + (spatialChan * 4)

		return channel


	def setNoteSets(self, noteSets):
		self.noteSets = noteSets
		self.newNoteSets = newNoteSets = map(lambda noteSet: map(lambda degree: (self.root+degree)%12, noteSet), noteSets)
