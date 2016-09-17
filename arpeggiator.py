class Arpeggiator:

	def __init__(self):
		self.onNotes = {}

	def handle(self, note, vel, onOff):
		if onOff == "on":
			self.onNotes[note] = vel
		if onOff == "off" and note in self.onNotes:
			del self.onNotes[note]
		print self.onNotes