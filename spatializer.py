import copy
import OSC
import heapq
import pickle

class Spatializer:

	def __init__(self, root, noteSets, fhInstance, chanInd):
		self.root = root
		self.noteSets = noteSets
		self.newNoteSets = map(lambda noteSet: map(lambda degree: (root+degree)%12, noteSet), noteSets)
		self.spatialize = True
		self.scClient = OSC.OSCClient()
		self.scClient.connect( ('127.0.0.1', 57120) )
		self.broadcastClient = OSC.OSCClient()
		self.broadcastClient.connect( ('127.0.0.1', 34345) ) #currently "broadcasting" to just Pydal, for safety
		self.broadcasting = False
		self.sustaining = True
		self.onNotes = {} #maps note to midi key
		self.normalForwardingBehavior = True
		self.chanInd = chanInd


		self.savedChords = [{} for i in range(100)]
		self.fhInstance = fhInstance
		self.fhInstance.superColliderServer.addMsgHandler("/saveChord-"+str(chanInd), self.saveChordHandler)
		self.fhInstance.superColliderServer.addMsgHandler("/playChord-"+str(chanInd), self.playChordHandler)
		self.fhInstance.superColliderServer.addMsgHandler("/utilityButton", self.handleFaderSave)

		#NOTE: using channelSeparation and spatialization on same instrument will cause undefined behavior
		self.separateChannels = False  
		self.noteToChanMap = {}
		#talking all extra bass channels and all drum channels except 1, on top of 4 "inst 2" channels
		self.openChannels = [1, 2, 5, 6, 7, 9, 10, 11, 13, 14, 15]  

		self.chordSetStack = []

		self.parameterBank = [[0]*12 for i in range(7)]

	#hardcoded for drone song
	def handleFaderSave(self, addr, tags, stuff, source):
		if stuff[1] == 1:
			self.parameterBank[int(stuff[0])] = copy.deepcopy(self.fhInstance.currentFaderVals[1])
		else:
			banksToString = lambda a: "-".join(map(lambda bank: ".".join(map(lambda slot: ",".join(map(str,slot)), bank)), a))
			currentFadersToString = lambda bank: ".".join(map(lambda slot: ",".join(map(str,slot)), bank))
			self.fhInstance.currentFaderVals[2] = copy.deepcopy(self.parameterBank[stuff[0]])
			msg = OSC.OSCMessage()
			msg.setAddress("/loadSceneFaders")
			msg.append(banksToString(self.fhInstance.faderBanks))
			msg.append(currentFadersToString(self.fhInstance.currentFaderVals))
			self.fhInstance.superColliderClient.send(msg)


	def handle(self, channel, note, vel, keyOnOff, launchpadKey, callFromModifiedBehavior=False):
		if self.normalForwardingBehavior or callFromModifiedBehavior:
			onOff = self.resolveOnOff(note, keyOnOff, launchpadKey)
			if onOff is None:
				return
			newChannel = self.getChan(note, channel, onOff)
			msg = OSC.OSCMessage()
			self.sendNote(newChannel, note, vel, onOff)
			self.broadcastNote(newChannel, note, vel, onOff)

	def heldNotesOff(self, chan):
		for note in self.onNotes:
			self.sendNote(chan, note, 0, "off")
			self.broadcastNote(chan, note, 0, "off")
			if note in self.noteToChanMap:
				self.sendNote(self.noteToChanMap[note], note, 0, "off")
				self.broadcastNote(self.noteToChanMap[note], note, 0, "off")
				del self.noteToChanMap[note]

	def sendNote(self, channel, note, vel, onOff):
		if self.broadcasting:
			return
		msg = OSC.OSCMessage()
		msg.setAddress("/spatializePlay")
		msg.append(channel)
		msg.append(note)
		msg.append(vel)
		msg.append(onOff)
		self.scClient.send(msg)

	def broadcastNote(self, channel, note, vel, onOff):
		if not self.broadcasting:
			return
		msg = OSC.OSCMessage()
		msg.setAddress("/broadcastNoteSelector-"+str(self.chanInd))
		msg.append(channel)
		msg.append(note)
		msg.append(vel)
		msg.append(onOff)
		self.broadcastClient.send(msg)


	def sendKeyColor(self, key, color):
		msg = OSC.OSCMessage()
		msg.setAddress("/moduleLights")
		msg.append(key)
		msg.append(color)
		msg.append(self.chanInd)
		self.scClient.send(msg)

	def resolveOnOff(self, note, keyOnOff, launchpadKey):
		if self.sustaining:
			if keyOnOff == "on":
				if note in self.onNotes:
					del self.onNotes[note]
					self.sendKeyColor(launchpadKey, -1)
					return "off"
				else:
					self.onNotes[note] = launchpadKey
					self.sendKeyColor(launchpadKey, 21)
					return "on"
		else:
			if not note in self.onNotes:
				return keyOnOff
	
	def getChord(self):
		return copy.deepcopy(self.onNotes)

	#chord is (midiNote -> launchpadKey) map
	def playChord(self, chord, channel=1):
		for note in copy.deepcopy(self.onNotes):
			self.handle(channel, note, 64, "on", self.onNotes[note])
		for note in chord:
			self.handle(channel, note, 64, "on", chord[note])


	def getChan(self, note, channel, onOff):
		if self.separateChannels:
			if onOff == "on":
				chan = heapq.heappop(self.openChannels)
				self.noteToChanMap[note] = chan
				return chan
			else:
				chan = self.noteToChanMap[note]
				if chan not in self.openChannels:
					heapq.heappush(self.openChannels, chan)
				del self.noteToChanMap[note]
				return chan
		if self.spatialize:
			spatialChan = 0
			for i in range(len(self.newNoteSets)):
				if note % 12 in self.newNoteSets[i]:
					spatialChan = i+1
			return channel + (spatialChan * 4)

		if onOff == "on":
			self.noteToChanMap[note] = channel
			return channel
		else:
			chan = self.noteToChanMap[note]
			if chan not in self.openChannels:
				heapq.heappush(self.openChannels, chan)
			del self.noteToChanMap[note]
			return chan

	def playChordHandler(self, addr, tags, stuff, source):
		self.playChord(self.savedChords[int(stuff[0])], self.chanInd)
		msg = OSC.OSCMessage()
		msg.setAddress("/chordPadIndFwd")
		msg.append(stuff[0])
		self.fhInstance.superColliderClient.send(msg)

	def saveChordHandler(self, addr, tags, stuff, source):
		self.saveChord(int(stuff[0]))

	def saveChord(self, ind):
		self.savedChords[ind] = self.getChord()
		print "saved", self.chanInd, self.getChord()

	def saveChordsToFile(self, filename):
		pickle.dump(self.savedChords, open(filename, "w"))

	def loadChordsFromFile(self, filename):
		self.chordSetStack.append(self.savedChords)
		self.savedChords = pickle.load(open(filename))
		nonNullChords = [x for x in range(len(self.savedChords)) if len(self.savedChords[x]) != 0] 
		chordIndexesString = ",".join(map(str, nonNullChords))
		msg = OSC.OSCMessage()
		msg.setAddress("/loadChords")
		msg.append(chordIndexesString)
		self.scClient.send(msg)

	def setNoteSets(self, noteSets):
		self.noteSets = noteSets
		self.newNoteSets = newNoteSets = map(lambda noteSet: map(lambda degree: (self.root+degree)%12, noteSet), noteSets)
