import OSC
import threading
import random
import copy
import phrase
import pickle
import itertools

#functionHanlder
class FH2:
	
	def __init__(self):
		self.superColliderClient = OSC.OSCClient()
		self.superColliderClient.connect( ('127.0.0.1', 57120) ) 

		self.superColliderServer = OSC.OSCServer(('127.0.0.1', 13371))
		self.serverThread = threading.Thread(target=self.superColliderServer.serve_forever)
		self.serverThread.daemon = False
		self.serverThread.start()

		self.topRowFunctions = [0]*8

		n = 4

		self.loops = [0 for i in range(100)]
		self.loopInfo = [{} for i in range(100)]

		#[(loops, loopInfo)]
		self.scenes = [0]*32 # scenes[18] is scene in 1st row 8th column of launchpad  
		self.sceneStack = []
		self.sceneCollectionsStack = []
		self.faderBanks = [[[0]*12 for i in range(4)] for j in range(4)]
		self.currentFaderVals = [[0]*12 for i in range(4)]

		#todo - update scales/roots here when changed programatically?
		self.scales = [[0, 2, 3, 5, 7, 8, 10] for i in range(n-1)] + [range(12)]
		self.roots = [60, 60, 36, 36]

		self.superColliderServer.addMsgHandler("/algRequest", self.handleAlgRequest)
		self.superColliderServer.addMsgHandler("/saveLoop", self.saveNewLaunchpadLoop)
		self.superColliderServer.addMsgHandler("/algRequestUpdate", self.updateChannel)
		self.superColliderServer.addMsgHandler("/loopPlay", self.loopPlay)
		self.superColliderServer.addMsgHandler("/saveScene", self.saveSceneHandler)
		self.superColliderServer.addMsgHandler("/playScene", self.playSceneHandler)
		self.superColliderServer.addMsgHandler("/faderSettingSave", self.saveFaderSetting)
		self.superColliderServer.addMsgHandler("/getCurrentFaderVals", self.recieveCurrentFaderVals)
		self.superColliderServer.addMsgHandler("/buttonForwarding", self.buttonForwardingHandler)
		self.superColliderServer.addMsgHandler("/miniLaunchpadTopRow", self.topRowHandler)
		self.superColliderServer.addMsgHandler("/pedalButton", self.pedalButtonHandler)		
		self.superColliderServer.addMsgHandler("/saveMetaInfo", self.saveMetaInfo)	
		self.superColliderServer.addMsgHandler("/metaInfoLoadRequest", self.metaInfoLoadRequestHandler)	


		self.pedalButtonFunc = lambda: 0

		self.channels = {} #key - int, val - (transFunc, rootMel)
		self.savedStrings = []
		self.buttonForwardingHandlers = [[] for i in range(n)]

		# leaderPadInd -> [(padIndex, delayFromLeader)]
		self.delays = {}
		self.superColliderServer.addMsgHandler("/xyToPython", self.padFollowerHandler)

	def addForwardingHandler(self, chanInd, handler):
		self.buttonForwardingHandlers[chanInd].append(handler)

	#stuff = [chan, note, vel, on/off, launchpadKeyMidi]
	def buttonForwardingHandler(self, addr, tags, stuff, source):
		for handler in self.buttonForwardingHandlers[stuff[0]]:
			handler.handle(*stuff)
	
	def pedalButtonHandler(self, addr, tags, stuff, source):
		return self.pedalButtonFunc()

	#stuff = [chanInd, bankNum, root, scale, loopString] 
	def handleAlgRequest(self, addr, tags, stuff, source):
		msg = OSC.OSCMessage()
		msg.setAddress("/algResponse")
		msg.append(int(stuff[0]))
		msg.append(int(stuff[1]))
		print "got from supercollider"
		print stuff
		hitList = self.stringToHitList(stuff[4])
		for h in hitList:
			h[1] += 5
		msg.append(self.hitListToString(hitList, scale, startBeat))
		self.superColliderClient.send(msg)

	#stuff = [bankNum, loopString, button] 	
	def saveNewLaunchpadLoop(self, addr, tags, stuff, source):
		self.savedStrings.append(stuff[2])
		hitList = self.stringToHitList(stuff[1])
		bankNum = stuff[0]
		button = stuff[2]
		self.loops[bankNum] = hitList
		self.loopInfo[bankNum]["button"] = button
		self.loopInfo[bankNum]["playing"] = True


	#stuff = [root, scaleString]

	#stuff = [metaInfoType, loopInd, info...]
	def saveMetaInfo(self, addr, tags, stuff, source):
		 if stuff[0] == "quadKey":
			self.saveQuadKeysMetaInfo(*stuff[:1])

	def saveQuadKeysMetaInfo(loopInd, rootStr, scalesStr):
		self.roots = [int(r) for r in rootStr.split(",")]
		self.scales[chanInd] = [[int(n) for n in scale.split(",")] for scale in scaleStr.split(".")]

	#stuff = [sceneInd]
	def metaInfoLoadRequestHandler(self, addr, tags, stuff, source):
		self.loadMetaInfo(stuff[0])

	def loadMetaInfo(self, sceneInd):
		sceneTuple = self.scenes[sceneInd]
		roots = sceneTuple[2]
		scales = sceneTuple[3]
		print roots, scales
		for i in range(4):
			self.rootScale(i, roots[i], ",".join(scales[i]))
		# todo - need to separate out quadKey logic from loop saving logic.
		# when implemented properly, the python modules of different interfaces
		# will be registered with the FH model, and when a scene is loaded this 
		# function will send a message to all of the modules that a load-scene has
		# occured, the message contaning the meta-info appropriate for that insturment
		# the instrument will then either update or not, depending on its push-update flag



	#stuff = [bankNum, playing(bool)]
	def loopPlay(self, addr, tags, stuff, source):
		self.loopInfo[stuff[0]]["playing"] = stuff[2]

	def resetButtonDestinations(self, destList):
		msg = OSC.OSCMessage()
		msg.setAddress("/resetButtonDestinations")
		msg.append(destList)
		self.superColliderClient.send(msg)

	@staticmethod 
	def stringToHitList(loopString):
		def splitHit(hitString):
			s = hitString.split(",")
			return [float(s[0]), int(s[1]), int(s[2]), int(s[3]), s[4]]
		recBuf = map(splitHit, loopString.split("-"))
		return recBuf

	@staticmethod
	def hitListToString(hitList, button, startBeat, playing=0):
		hitToStringList = lambda h: ['%f' % h[0]] + map(str, h[1:])
		return str(button) + " " + "-".join(map(lambda h: ",".join(hitToStringList(h)), hitList)) + " " + str(playing)


	def sceneToString(self, loops, loopInfo):
		sceneStringList = []
		for i in range(len(loops)):
				if loops[i] != 0:
					sceneStringList.append(self.hitListToString(loops[i], loopInfo[i]["button"], "startBeat", 1 if loopInfo[i]["playing"] else 0))
				else:
					sceneStringList.append("none")
		return ":".join(sceneStringList)

	def sendScene(self, ind, loops, loopInfo):
		msg = OSC.OSCMessage()
		msg.setAddress("/sendScene")
		msg.append(self.sceneToString(loops, loopInfo))
		msg.append(ind)
		self.superColliderClient.send(msg)


	def getScene(self):
		return (self.loops, self.loopInfo, self.roots, self.scales, self.faderBanks, self.currentFaderVals)

	def sendCurrentScene(self):
		self.sendScene(*self.getScene())

	#stuff[0] is ind of pad to which to save scene
	def saveSceneHandler(self, addr, tags, stuff, source):
		self.saveScene(int(stuff[0]))

	def saveScene(self, ind):
		c = copy.deepcopy
		self.scenes[ind] = map(c, self.getScene())
		msg = OSC.OSCMessage()
		msg.setAddress("/getCurrentFaderVals")
		msg.append(ind)
		self.superColliderClient.send(msg)

	#msg[0] is cuffentFaderVals string, msg[1] is sceneIndex to save them in
	def recieveCurrentFaderVals(self, addr, tags, stuff, source):
		print "GOT CURRENT FADER VALS"
		self.currentFaderVals = map(lambda s: map(int, s.split(",")), stuff[0].split("."))
		currentFadersToString = lambda bank: ".".join(map(lambda slot: ",".join(map(str,slot)), bank))
		self.scenes[stuff[1]][5] = copy.deepcopy(self.currentFaderVals)


	#stuff[0] is ind of pad corresponding to which scene to play
	def playSceneHandler(self, addr, tags, stuff, source):
		self.playScene(int(stuff[0]))

	def setCurrentScene(self, sceneTuple):
		self.loops, self.loopInfo, self.roots, self.scales, self.faderBanks, self.currentFaderVals = sceneTuple

	def playScene(self, ind):
		c = copy.deepcopy
		self.sceneStack.append(map(c, self.getScene()))
		self.loadMetaInfo(ind)
		self.setCurrentScene(c(self.scenes[ind]))
		self.sendCurrentScene()

	def undoScenePlay(self):
		self.setCurrentScene(self.sceneStack.pop())
		self.sendCurrentScene()

	def loadScenesFromFile(self, fileName):
		self.sceneCollectionsStack.append(copy.deepcopy(self.scenes))
		self.scenes = pickle.load(open(fileName))
		nonNullScenes = [x for x in range(len(self.scenes)) if self.scenes[x] != 0] 
		for i in range(len(self.scenes)):
			if self.scenes[i] != 0:
				self.sendScene(i, self.scenes[i][0], self.scenes[i][1])
			else:
				msg = OSC.OSCMessage()
				msg.setAddress("/sendScene")
				msg.append("none")
				msg.append(i)
				self.superColliderClient.send(msg)

	def saveScenesToFile(self, fileName):
		pickle.dump(self.scenes, open(fileName, "w"))

	def saveFaderSetting(self, addr, tags, stuff, source):
		print "fader saved"
		self.lastFader = stuff
		self.faderBanks[stuff[0]][stuff[1]] = map(int, stuff[2].split(","))

	def end(self):
		self.superColliderServer.close()

	def startChannel(self, chanInd, transFunc, rootMel):
		#self.stopChannel(chanInd)
		self.channels[chanInd] = (transFunc, rootMel)
		msg = OSC.OSCMessage()
		msg.setAddress("/algStart")
		msg.append(chanInd)
		msg.append(self.hitListToString(rootMel, 'fillerStuff', 'fillerStuff'))
		self.superColliderClient.send(msg)

	#stuff[0] is channelInd
	def updateChannel(self, addr, tags, stuff, source):
		chanInd = stuff[0]
		transFunc = self.channels[chanInd][0]
		rootMel = self.channels[chanInd][1]
		newMel = transFunc(rootMel)
		msg = OSC.OSCMessage()
		msg.setAddress("/algRecieveUpdate")
		msg.append(chanInd)
		msg.append(self.hitListToString(newMel, 'fillerStuff', 'fillerStuff'))
		self.superColliderClient.send(msg)

	def rootScale(self, chan=0, root=0, scale='minor'):
		msg = OSC.OSCMessage()
		msg.setAddress('/rootScale')
		msg.append(root)
		keyval = scale
		if scale in phrase.modes.keys():
			keyval = ",".join(map(str, phrase.modes[scale]))
		else:
			keyval = scale.split(',')
			keyval = map(lambda a: int(a.strip()), keyval)
			if len(keyval) == 0:
				raise StopIteration("malformed scale string")
			keyval = ','.join(str(keyval))
		msg.append(keyval)
		msg.append(chan)
		self.superColliderClient.send(msg)	

	def stopChannel(self, chanInd):
		msg = OSC.OSCMessage()
		msg.setAddress("/algStop")
		msg.append(chanInd)
		self.superColliderClient.send(msg)

	def topRowHandler(self, addr, tags, stuff, source):
		if stuff[1] == 127:
			self.topRowFunctions[stuff[0]]()

	# followerPadDelay is [(padIndex, delayFromLeader)]
	def setFollowers(self, leaderPad, *followerPadDelay):
		self.delays[leaderPad] = followerPadDelay

	#stuff - [padInd, xVal, yVal]
	def padFollowerHandler(self, addr, tags, stuff, source):
		if stuff[0] in self.delays:    
			for padDelay in self.delays[stuff[0]]:
				msg = OSC.OSCMessage()
				msg.setAddress("/xyFollowing")
				msg.append(padDelay[0])
				msg.append(stuff[1])
				msg.append(stuff[2])
				msg.append(padDelay[1])
				self.superColliderClient.send(msg)

def oneHitShift(hitList):
	i1 = random.randint(0, len(hitList)-1)
	i2 = random.randint(0, len(hitList)-1)
	h2 = copy.deepcopy(hitList)
	hit = hitList[i1]
	h2.pop(i1)
	h2.insert(i2, hit)
	return h2

def notesByBeat(noteList):
	byBeat = [[] for i in range(int(noteList[-1][0])+1)]
	#print "BY BEAT", byBeat
	for n in noteList:
		#print n
		byBeat[int(n[0])].append([n[0]%1] + n[1:])
	return byBeat

def flattenByBeat(byBeat):
	flattened = []
	for i in range(len(byBeat)):
		flattened += map(lambda note: [note[0]+i] + note[1:], byBeat[i])
	return flattened


#converts to a list of (timeStamp, midiNote, velocity, channel, duration)
#TODO: fix assumtion that we start with note on, and that
#there is strict alternation of note on/off per midiNote
def hitListToNoteList(hitList):
	noteToStartStop = {}
	timeSoFar = 0
	for h in hitList[:len(hitList)-1]:
		timeSoFar += h[0]
		if h[1] not in noteToStartStop:
			noteToStartStop[h[1]] = [(timeSoFar,  h[2], h[3], h[4])] #time, velocity, midiChan, on/off
		else:
			noteToStartStop[h[1]].append((timeSoFar, h[2], h[3], h[4]))


	noteList = []
	# for n in noteToStartStop:
	# 	print n, noteToStartStop[n]
	for midiNote in noteToStartStop:
		startStop = noteToStartStop[midiNote]
		for i in range(0, len(startStop), 2):
			if len(startStop) == i+1:
				noteList.append([startStop[i][0], midiNote, startStop[i][1], startStop[i][2], int(timeSoFar)+0.95-startStop[i][0]])
			else:
				#time, midiNote, onVelocity, midiChan, duration
				noteList.append([startStop[i][0], midiNote, startStop[i][1], startStop[i][2], startStop[i+1][0]-startStop[i][0]])

	noteList.sort()
	return noteList



def noteListToHitList(noteList):
	intermediateHitList = []
	for n in noteList:
		intermediateHitList.append([n[0], n[1], n[2], n[3], 'on'])
		intermediateHitList.append([n[0]+n[4], n[1], n[2], n[3], 'off'])

	intermediateHitList.sort()
	timeAfterLastHit = int(intermediateHitList[-1][0])+1 - intermediateHitList[-1][0]
	#print intermediateHitList
	for i in range(len(intermediateHitList)-1, 0, -1):
		intermediateHitList[i][0] -= intermediateHitList[i-1][0]

	intermediateHitList.append([timeAfterLastHit, 0, 0, 0, 'timeAfterLastHit'])

	return intermediateHitList




#TODO - figure out higher level organization of melody manipulation module
# 1. need a standard format to work with, make it a class (noteList as standard format?)
#	- notelist manipulation can result in hitlsits that aren't creatable when playing with hands,
#	  make sure this won't result in any hanging notes or weird length loops

# functions:
# splitAtBeats - splits a notelist into a list of segments starting at the indicies given (ending at the next largest index)
#	- can be combined well with "a c b b <a c, b c>" style sequencing
# 
# 
# 




def beatShuffle(hitList, start=None, end=None):
	#TODO - handle timeAfterLastBeat properly when shuffle includes last beat
	beatList = notesByBeat(hitListToNoteList(hitList))
	s = 0 if (start is None or start >= len(beatList)) else start
	e = len(beatList) if (end is None or end >= len(beatList) or end < s) else end 
	shuffleSeg = beatList[s:e]
	random.shuffle(shuffleSeg)
	rejoined = beatList[:s] + shuffleSeg + beatList[e:]
	return noteListToHitList(flattenByBeat(rejoined))

def scaleNotesCalc(root, scale, n):
	notes = [0]*n
	for i in range(n):
		notes[i] = root + (i/len(scale))*12 + scale[i%len(scale)] 
	return notes

#TODO - fix assumption that root note is 60
def randTranspose(hitList, root, scale, down=3, up=3, start=None, end=None, beatIndexed=True, intraBeatRandom=False):
	hitList = copy.deepcopy(hitList)
	noteList = hitListToNoteList(hitList)
	scaleNotes = scaleNotesCalc(root-36, scale, 80)
	if beatIndexed:
		beatList = notesByBeat(noteList)
		s = 0 if (start is None or start in range(len(beatList))) else start
		e = len(beatList) if (end is None or end >= len(beatList) or end < s) else end
		beatList = notesByBeat(noteList)
		for b in beatList[s:e]:
			r = random.randint(-1*down, up)
			for n in b:
				r = random.randint(-1*down, up) if intraBeatRandom else r
				#print n[1], r, scaleNotes.index(n[1]) + r
				n[1] = scaleNotes[scaleNotes.index(n[1]) + r]
		noteList = flattenByBeat(beatList)
	else:
		s = 0 if (start is None or start >= len(hitList)) else start
		e = len(hitList) if (end is None or end >= len(hitList) or end < s) else end
		for n in noteList:
			n[1] = scaleNotes[scaleNotes.index(n[1]) + random.randint(-1*down, up)]
	
	return noteListToHitList(noteList)

def scaleTranspose(hitList, root, scale, amount):
	hitList = copy.deepcopy(hitList)
	noteList = hitListToNoteList(hitList)
	scaleNotes = scaleNotesCalc(root-36, scale, 80)
	for n in noteList:
			n[1] = scaleNotes[scaleNotes.index(n[1]) + amount]
	return noteListToHitList(noteList)

def vectorTranspose(hitList, root, scale, transVec):
	hitList = copy.deepcopy(hitList)
	noteList = hitListToNoteList(hitList)
	scaleNotes = scaleNotesCalc(root-36, scale, 80)
	beatList = notesByBeat(noteList)
	for i in range(len(beatList)):
		b = beatList[i]
		for n in b:
			transVal = transVec[i%len(transVec)]
			n[1] = scaleNotes[scaleNotes.index(n[1]) + transVal]
	noteList = flattenByBeat(beatList)
	
	return noteListToHitList(noteList)

def shiftTranspose(hitList, root, scale, transVec):
	hitList = copy.deepcopy(hitList)
	noteList = hitListToNoteList(hitList)
	scaleNotes = scaleNotesCalc(root-36, scale, 80)
	beatList = notesByBeat(noteList)
	for i in range(len(beatList)):
		b = itertools.chain(*beatList[i:])
		for n in b:
			transVal = transVec[i%len(transVec)]
			n[1] = scaleNotes[scaleNotes.index(n[1]) + transVal]
	noteList = flattenByBeat(beatList)
	
	return noteListToHitList(noteList)

def randBeatMove(hitList):
	beatList = notesByBeat(hitListToNoteList(hitList))
	i = random.randint(0, len(beatList)-1)
	k = random.choice(list(set(range(len(beatList))) - set([i])))
	if i > k:
		beatList.insert(k, beatList.pop(i))
	else :
		beatList.insert(k-1, beatList.pop(i))
	return noteListToHitList(flattenByBeat(beatList))

#todo - this only works if vector and numBeats is the same
def vectorBeatPermute(hitList, vector):
	beatList = notesByBeat(hitListToNoteList(hitList))
	newBeatList = [beatList[i%len(beatList)] for i in vector]
	return noteListToHitList(flattenByBeat(newBeatList))


def treeFunc(hitList, root, scale, p=0.3):
	if random.uniform(0, 1) > p :
		i = random.randint(0, len(hitList))
		j = random.randint(0, len(hitList))
		return randTranspose(hitList, root, scale, start=min(i, j), end=max(i, j), beatIndexed=False)
	else:
		return randBeatMove(hitList)


def warp(hitList, warpPoint, constant=.2, exponent=1):
	noteList = hitListToNoteList(hitList)
	def calcWarp(time, warpPoint, constant, exponent):
		if(time == warpPoint): #todo - imlpement "event horizon check"
			return 0
		dist = constant/abs(warpPoint-time)**exponent
		return dist if warpPoint > time else -1 * dist
	warpList = map(lambda note: calcWarp(note[0], warpPoint, constant, exponent), noteList)
	for i in range(len(noteList)):
		noteList[i][0] += warpList[i]
	return noteListToHitList(noteList)

# noteSets is up to 3 sets of notes, each containing ints [0-11]
# each set corresponds to a spatialization channel
# if one of [0-11] is not specificied in a noteSet, it is played thru the normal channel 
def spatialize(hitList, root, noteSets):
	newNoteSets = map(lambda noteSet: map(lambda degree: (root+degree)%12, noteSet), noteSets)
	newHitList = copy.deepcopy(hitList)
	for hit in newHitList:
		for i in range(len(noteSets)):
			if hit[1] % 12 in newNoteSets[i]:
				hit[3] = (i+1) * 4
	return newHitList 

def main():
	hl = warp(hitList, 3)
	for h in hitListToNoteList(hl):
		print h

	hitString = '19 0.015517354926804,36,90,3,on-0.069313140281711,36,0,3,off-0.40111655031738,36,88,3,on-0.13826123650379,36,0,3,off-0.30373582635919,36,86,3,on-0.068988503365478,36,0,3,off-0.37323516937636,36,94,3,on-0.16584420671271,36,0,3,off-0.37435709074858,41,102,3,on-0.22119814726626,41,0,3,off-0.52463878235438,41,99,3,on-0.17918737393996,41,0,3,off-0.58129390059232,41,97,3,on-0.17996301558244,41,0,3,off-0.3181157736951,36,108,3,on-0.25061781998902,36,0,3,off-0.8401201725943,36,97,3,on-0.29228857541083,36,0,3,off-0.75886568925363,41,99,3,on-0.2358261358357,41,0,3,off-0.7734233730412,41,111,3,on-0.27621152805202,41,0,3,off-0.65788063380083,0,0,0,timeAfterLastHit 14'
	hitString = '19 0.0155173549268,36,90,3,on-0.0693131402817,36,0,3,off-0.401116550317,36,88,3,on-0.138261236504,36,0,3,off-0.303735826359,36,86,3,on-0.0689885033655,36,0,3,off-0.373235169376,36,94,3,on-0.165844206713,36,0,3,off-0.374357090749,41,102,3,on-0.221198147266,41,0,3,off-0.524638782354,41,99,3,on-0.17918737394,41,0,3,off-0.581293900592,41,97,3,on-0.179963015582,41,0,3,off-0.318115773695,36,108,3,on-0.250617819989,36,0,3,off-0.840120172594,36,97,3,on-0.292288575411,36,0,3,off-0.758865689254,41,99,3,on-0.235826135836,41,0,3,off-0.773423373041,41,111,3,on-0.276211528052,41,0,3,off-0.657880633801,0,0,0,timeAfterLastHit 14'
	hl1 = '59 0,67,115,1,on-0.35805304900001,67,0,1,off-0.099085806999994,68,114,1,on-0.33568892400001,68,0,1,off-0.11485539500001,70,93,1,on-0.381267638,70,0,1,off-0.18247946000002,72,114,1,on-0.36613351199998,72,0,1,off-0.16243621499999,0,0,0,timeAfterLastHit 242'
	hl2 = '69 0,67,108,1,on-0.44206642100005,68,86,1,on-0.156972967,67,0,1,off-0.31932736300001,70,58,1,on-0.11475639299999,68,0,1,off-0.39217421299998,72,91,1,on-0.07848408000001,70,0,1,off-0.49621856299996,0,0,0,timeAfterLastHit 275'
	hl3 = '59 0.00026503200000061,67,116,1,on-0.109492002,67,0,1,off-0.114887669,67,97,1,on-0.083770298999999,67,0,1,off-0.150910389,67,113,1,on-0.094081841000001,67,0,1,off-0.162514201,67,114,1,on-0.083863190000001,67,0,1,off-0.177834871,67,117,1,on-0.083826460000001,67,0,1,off-0.156259629,67,106,1,on-0.073450127999999,67,0,1,off-0.188066174,67,110,1,on-0.083808517,67,0,1,off-0.173343166,67,107,1,on-0.073152808,67,0,1,off-0.182253786,67,112,1,on-0.073165353,67,0,1,off-0.167248956,67,97,1,on-0.068336707,67,0,1,off-0.198340459,67,97,1,on-0.062599650000001,67,0,1,off-0.188070831,67,105,1,on-0.083570547000001,67,0,1,off-0.172715621,68,118,1,on-0.078436826999999,68,0,1,off-0.151519889,68,111,1,on-0.072601442,68,0,1,off-0.172986674,68,107,1,on-0.062571509000001,68,0,1,off-0.193675872,68,117,1,on-0.083643336000002,68,0,1,off-0.178736165,0,0,0,timeAfterLastHit 4'
	# print FH.hitListToString(*FH.stringToHitList(hitString)) == hitString

	hitList = [[0, 60, 60, 1, "on"], [.75, 60, 60, 1, "off"], [.25, 61, 60, 1, "on"], [.75, 61, 60, 1, "off"], [.25, 62, 60, 1, "on"], [.75, 62, 60, 1, "off"], [.25, 63, 60, 1, "on"], [.75, 63, 60, 1, "off"], [.25, 0, 0, 1, "timeAfterLastHit"]]

	newHS = FH.stringToHitList(hl3)[0]
	noteList = hitListToNoteList(newHS)
	codecHS = noteListToHitList(noteList)
	hl = randTranspose(newHS, 60, [0, 2, 3, 5, 7, 8, 10])

	# print hitList
	# print beatShuffle(newHS)
	# for n in noteList:
	# 	print n
	# tot1 = 0
	# for h in newHS:
	# 	tot1 += h[0]
	# 	print h
	# tot2 = 0
	# for h in codecHS:
	# 	tot2+= h[0]
	# 	print h
	# print tot1, tot2
	# beats = notesByBeat(noteList)
	# for b in beats:
	# 	print 
	# notes = flattenByBeat(beats)
	# for n in notes:
	# 	print n
	# print hitListToString(*stringToHitList(hitString))


	#print hitListToNoteList(hl)

def transformTranspositionVector(transVec, frac=0.25):
	transformationCells = random.sample(range(len(transVec)), int(frac*len(transVec)))
	newVec = copy.deepcopy(transVec)
	for c in transformationCells:
		newVec[c] += random.choice([-1, 1])
	return newVec
#TODO: print the strings of a few different buffers as test cases 




if __name__ == '__main__':
	main()


