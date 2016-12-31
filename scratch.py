# leaderPadInd -> [(padIndex, delayFromLeader)]
delays = {}
self.superColliderServer.addMsgHandler("/xyToPython", self.padFollowerHandler)

# followerPadDelay is [(padIndex, delayFromLeader)]
def setFollowers(leaderPad, *followerPadDelay):
    delays[leaderPad] = followerPadDelay

#stuff - [padInd, xVal, yVal]
def padFollowerHandler(self, addr, tags, stuff, source):    
    for padDelay in delays[stuff[0]:
        msg = OSC.OSCMessage()
        msg.setAddress("/xyFollowing")
        msg.append(padDelay[0])
        msg.append(stuff[1])
        msg.append(stuff[2])
        msg.append(padDelay[1])
        self.superColliderClient.send(msg)

