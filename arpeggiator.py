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
			#send note
			if len(self.onOntes) == 1:
				self.channel.play(self.pattern)
		if onOff == "off" and note in self.onNotes:
			del self.onNotes[note]
			if len(self.onNotes) == 0:
				self.channel.stop()
			#send note
		print self.onNotes 


	def kill(self):
