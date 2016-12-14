import copy
import OSC
class Spatializer:

	def __init__(self, root, noteSets):
		self.root = root
		self.noteSets = noteSets
		self.newNoteSets = map(lambda noteSet: map(lambda degree: (root+degree)%12, noteSet), noteSets)
		self.client = OSC.OSCClient()
		self.client.connect( ('127.0.0.1', 57120) )

	def handle(self, channel, note, vel, onOff):
		msg = OSC.OSCMessage()
		msg.setAddress("/spatializePlay")
		msg.append(self.getChan(note, channel))
		msg.append(note)
		msg.append(vel)
		msg.append(onOff)
		self.client.send(msg)

	def getChan(self, note, channel):
		spatialChan = 0
		for i in range(len(self.newNoteSets)):
			if note % 12 in self.newNoteSets[i]:
				spatialChan = i+1
		return channel + (spatialChan * 4)


	def setNoteSets(self, noteSets):
		self.noteSets = noteSets
		self.newNoteSets = newNoteSets = map(lambda noteSet: map(lambda degree: (self.root+degree)%12, noteSet), noteSets)
