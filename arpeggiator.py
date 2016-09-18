import PydalChannel
import OSC

class Arpeggiator:

	def __init__(self, midiChannel, pydal, pattern):
		self.onNotes = {}
		self.midiChannel = midiChannel
		self.pydalInstance = pydal 
		self.channel = pydal.newArpeggiatorChannel(midiChannel)
		self.pattern = pattern


	def handle(self, note, vel, onOff):
		if onOff == "on":
			self.onNotes[note] = vel

			msg = OSC.OSCMessage()
			msg.setAddress("/forwardNotes")
			msg.append(note)
			msg.append(vel)
			msg.append(onOff)
			self.pydal.superColliderClient.sendMsg(msg)

			if len(self.onOntes) == 1:
				self.channel.play(self.pattern)
		if onOff == "off" and note in self.onNotes:
			del self.onNotes[note]
			if len(self.onNotes) == 0:
				self.channel.stop()
			#send note
		print self.onNotes

	def sendNoteUpdate(self, note, vel onOff):
		msg = OSC.OSCMessage()
		msg.setAddress("/forwardNotes")
		msg.append(note)
		msg.append(vel)
		msg.append(onOff)
		self.pydal.superColliderClient.sendMsg(msg)

	def kill(self):
