import PydalChanel
import OSC

class Arpeggiator:

	def __init__(self, midiChannel, pydalInstance, pattern):
		self.onNotes = {}
		self.midiChannel = midiChannel
		self.pydalInstance = pydalInstance 
		self.channel = pydalInstance.newArpeggiatorChannel(midiChannel)
		self.pattern = pattern


	def handle(self, chan, note, vel, onOff):
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
		self.pydalInstance.superColliderClient.send(msg)
