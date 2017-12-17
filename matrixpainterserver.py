#!/usr/bin/python
from BaseHTTPServer import BaseHTTPRequestHandler,HTTPServer
from os import curdir, sep
import cgi
import logging
import OSC
import json
import threading
import pickle 

PORT_NUMBER = 8899

# scClient = OSC.OSCClient()
# scClient.connect( ('127.0.0.1', 57120) ) 
maxClient = OSC.OSCClient()
maxClient.connect( ('127.0.0.1', 5432) ) 
scClient = OSC.OSCClient()
scClient.connect( ('127.0.0.1', 57120) ) 
scServer = OSC.OSCServer(('127.0.0.1', 12345))
matrixStrings = {}

#stuff[0] is padInd, stuff[1] is colorStr, stuff[2] is selectStr
def recieveMatrixStr(addr, tags, stuff, source):
	matrixStrings[int(stuff[0])] = (stuff[1], stuff[2])

def saveAllMatricies(addr, tags, stuff, source):
	pickle.dump(open(stuff[0], "w"))

def loadAllMatricies(addr, tags, stuff, source):
	matrixStrings = pickle.load(open(stuff[0]))

scServer.addMsgHandler("/processMatrices", recieveMatrixStr)

scThread = threading.Thread(target=scServer.serve_forever)

#This class will handles any incoming request from
#the browser 
class myHandler(BaseHTTPRequestHandler):
	
	#Handler for the GET requests
	def do_GET(self):
		if self.path=="/":
			self.path="/matrixpainter.html"

		try:
			#Check the file extension required and
			#set the right mime type

			sendReply = False
			if self.path.endswith(".html"):
				mimetype='text/html'
				sendReply = True
			if self.path.endswith(".jpg"):
				mimetype='image/jpg'
				sendReply = True
			if self.path.endswith(".gif"):
				mimetype='image/gif'
				sendReply = True
			if self.path.endswith(".js"):
				mimetype='application/javascript'
				sendReply = True
			if self.path.endswith(".css"):
				mimetype='text/css'
				sendReply = True

			if sendReply == True:
				#Open the static file requested and send it
				f = open(curdir + sep + self.path) 
				self.send_response(200)
				self.send_header('Content-type',mimetype)
				self.end_headers()
				self.wfile.write(f.read())
				f.close()
			return

		except IOError:
			self.send_error(404,'File Not Found: %s' % self.path)

	#Handler for the POST requests
	def do_POST(self):
		logging.error(self.headers)
		print "POST PATH", self.path, self.headers 
		# print "CONTENT", self.rfile.readline()
		form = cgi.FieldStorage(
			fp=self.rfile, 
			headers=self.headers,
			environ={'REQUEST_METHOD':'POST',
	                 'CONTENT_TYPE':self.headers['Content-Type'],
		})
		if self.path=="/send":
			
			# msg = OSC.OSCMessage()
			# msg.setAddress("/paintedMatrix/"+form['name'].value)
			# msg.append(form['height'].value)
			# msg.append(form['width'].value)
			matrixList = map(lambda i: int(i)*255, form['matrixstring'].value.split(","))
			# msg.append(matrixList)
			# scClient.send(msg)

			msg2 = OSC.OSCMessage()
			msg2.setAddress("/paintedMatrix/"+form['name'].value)
			msg2.append(matrixList)
			maxClient.send(msg2)
			self.send_response(200)
			self.end_headers()
		if self.path == "/save":
			matrixfile = open(form['name'].value, "w")
			matrixfile.write("height: " + str(form['height'].value) + "\n")
			matrixfile.write("width: " + str(form['width'].value) + "\n")
			matrixfile.write("matrixstring: " + str(form['matrixstring'].value) + "\n")
			matrixfile.write("skeleton: " + str(form['skeleton'].value) + "\n")
			matrixfile.close()
			self.send_response(200)
			self.end_headers()
		if self.path == "/open":
			matrixfileLines = open(form['name'].value).read().split("\n")
			height = int(matrixfileLines[0].split(": ")[1])
			width = int(matrixfileLines[1].split(": ")[1])
			matrixstring = matrixfileLines[2].split(": ")[1]
			skeleton = matrixfileLines[3].split(": ")[1]
			print "load skeleton", skeleton
			responseStr =json.dumps({"height": height, "width": width, "matrixstring": matrixstring, "skeleton": skeleton}, separators=(",", ":"))		
			self.send_response(200)
			self.end_headers()
			self.wfile.write(responseStr)
		if self.path == "/processGrid":
			responseStr = json.dumps
			self.send_response(200)
			self.end_headers()
			self.wfile.write(responseStr)
		if self.path == "/skeleton":
			msg = OSC.OSCMessage()
			msg.setAddress("/gridSkeleton")
			msg.append(json.loads(form['skeleton'].value))
			print msg
			scClient.send(msg)
			self.send_response(200)
			self.end_headers()
			self.wfile.write("sent skeleton")



			
try:
	#Create a web server and define the handler to manage the
	#incoming request
	server = HTTPServer(('', PORT_NUMBER), myHandler)
	print 'Started httpserver on port ' , PORT_NUMBER
	
	#Wait forever for incoming htto requests
	server.serve_forever()

except KeyboardInterrupt:
	print '^C received, shutting down the web server'
	scServer.close()
	scThread.join()
	server.socket.close()