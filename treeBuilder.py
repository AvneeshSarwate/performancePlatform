import treeLanguage as tl 
import copy

def main():

	inc = lambda a: a+1	
	inc = Counter()
	tree = TreeBuilder(0, inc)
	tree.execute( '(\/! ^)*3 \/ (\/! >!*3 ^ >)*3') # '\/! \/! >! >! <  < >!'
	print [c.value for c in tree.root.children[0].children]
	levels = tree.nodesByDepth()
	for l in levels:
		print l 
	print toDotFile("test1", tree.root)

def toDotFile(fileName, tree):
		el = []
		def addEdges(node, edgeList):
			for c in node.children:
				edgeList.append(str(node.value) + "->" + str(c.value))
				addEdges(c, edgeList)
		addEdges(tree, el)
		return "digraph " + fileName + " { \n" + "\n".join(el) + "\n}"




class Counter:

	def __init__(self):
		self.count = 0

	def __call__(self, arg):
		self.count += 1
		return self.count 

class TreeBuilder:

	# Given a "flattened" token list, when trying to find what function matches
	# what token, first split the token by ":" to get the "function key."
	# This will allow you to use indexing for move[down, left, right]
	def __init__(self, rootValue, transformationFunc, fullTreeDepth=0, childNumFunc=None):
		self.root = Node(rootValue)
		self.currentNode = self.root
		self.transFunc = transformationFunc
		self.siblingInd = 0
		# nodes do not know who their siblings are. this stack lets you properly 
		# handle sibling state when traversing up and down the tree
		self.siblingIndStack = [0] 
		self.traversalStack = []

		#only used with executeStepwise()
		self.traversalSteps = []
		self.traversalInd = 0
		self.traversalString = ""

		self.nonTraversingSymbols = ["+"]

		self.funcMap = {}
		self.funcMap['\/'] = self.moveDown
		self.funcMap['^'] = self.moveUp
		self.funcMap['<'] = self.moveLeft
		self.funcMap['>'] = self.moveRight
		self.funcMap['\/!'] = self.newDown
		self.funcMap['<!'] = self.newLeft
		self.funcMap['>!'] = self.newRight
		self.funcMap["+"] = self.stackPush
		self.funcMap["-"] = self.stackPop
		self.funcMap["_"] = lambda symbol: None

		if fullTreeDepth > 0:
			if childNumFunc is None:
				childNumFunc = lambda depth: 2
			self._buildTree(self.root, 0, fullTreeDepth, self.transFunc, childNumFunc)

	def _buildTree(self, node, depth, maxDepth, transFunc, childNumFunc):
		if depth == maxDepth:
			return
		else:
			for i in range(childNumFunc(depth)):
				newVal = transFunc(node.value)
				newNode = Node(newVal, node)
				node.children.append(newNode)
				newNode.treePosition = node.treePosition + "-" + str(len(node.children)-1)
				self._buildTree(newNode, depth+1, maxDepth, transFunc, childNumFunc)

	def isNonTraversingSymbol(self, symbol):
		return symbol in self.nonTraversingSymbols

	def stackPush(self, symbol):
		self.traversalStack.append((self.currentNode, self.siblingInd, copy.deepcopy(self.siblingIndStack)))

	def stackPop(self, symbol):
		self.currentNode, self.siblingInd, self.siblingIndStack = self.traversalStack.pop()

	def moveDown(self, symbol):
		ind = int(symbol.split(":")[1]) if ":" in symbol else 0
		if len(self.currentNode.children) != 0:
			self.siblingIndStack.append(self.siblingInd)
			self.siblingInd = ind%len(self.currentNode.children)
			self.currentNode = self.currentNode.children[self.siblingInd]

	#todo: include indexes for moving up? 
	def moveUp(self, symbol):
		if not self.currentNode.parent is None:
			self.siblingInd = self.siblingIndStack.pop()
			self.currentNode = self.currentNode.parent

	def moveRight(self, symbol):
		ind = int(symbol.split(":")[1]) if ":" in symbol else 1
		#print self.currentNode.value, self.siblingInd , ind, len(self.currentNode.parent.children), "value", self.currentNode.value
		self.siblingInd = (self.siblingInd + ind) % len(self.currentNode.parent.children)
		self.currentNode = self.currentNode.parent.children[self.siblingInd]
		#print self.currentNode.value

	def moveLeft(self, symbol):
		ind = int(symbol.split(":")[1]) if ":" in symbol else 1
		self.siblingInd = (self.siblingInd - ind) % len(self.currentNode.parent.children)
		self.currentNode = self.currentNode.parent.children[self.siblingInd]

	def newDown(self, symbol):
		newVal = self.transFunc(self.currentNode.value)
		newNode = Node(newVal, self.currentNode)
		self.currentNode.children.append(newNode)
		newNode.treePosition = self.currentNode.treePosition + "-" + str(len(self.currentNode.children)-1)
		self.siblingIndStack.append(self.siblingInd)
		self.siblingInd = len(self.currentNode.children) - 1
		self.currentNode = newNode
		#TODO: - hanlde creating new siblings for tree root

	def newRight(self, symbol):
		newVal = self.transFunc(self.currentNode.value)
		newNode = Node(newVal, self.currentNode.parent)
		self.currentNode.parent.children.insert(self.siblingInd+1, newNode)
		newNode.treePosition = self.currentNode.parent.treePosition + "-" + str(self.siblingInd+1)
		#TODO: modify sibling ind of all subsequent silings
		for c in self.currentNode.parent.children[self.siblingInd+2:]:
			newLastPosition = str(int(c.treePosition.split("-")[-1])+1)
			positionSplit = c.treePosition.split("-")
			positionSplit[-1] = newLastPosition
			c.treePosition = "-".join(positionSplit)
		self.currentNode = newNode
		self.siblingInd += 1

	def newLeft(self, symbol):
		newVal = self.transFunc(self.currentNode.value)
		newNode = Node(newVal, self.currentNode.parent)
		self.currentNode.parent.children.insert(self.siblingInd - 1, newNode)
		newNode.treePosition = self.currentNode.parent.treePosition + "-" + str(max(self.siblingInd - 1, 0))
		#TODO: modify sibling ind of all subsequent silings
		for c in self.currentNode.parent.children[self.siblingInd+1:]:
			newLastPosition = str(int(c.treePosition.split("-")[-1])+1)
			positionSplit = c.treePosition.split("-")
			positionSplit[-1] = newLastPosition
			c.treePosition = "-".join(positionSplit)
		self.currentNode = newNode

	def execute(self, treeString):
		actions = tl.parse(treeString).split(" ")
		traversedVariants = []
		for a in actions:
			actionType = a.split(":")[0].strip('@')
			self.funcMap[actionType](a)
			if "@" not in a and not self.isNonTraversingSymbol(a):
				traversedVariants.append(self.currentNode.value)
		return copy.deepcopy(traversedVariants)
		#todo: return the sequence of values corresponding to the sequence of nodes
		#traversed by the commands. should there be a special character (eg the @ in '\/@'')
		#that indicates whether you want the result of that command included in the 
		#values list returned?

	def executeStepwise(self, treeString):
		parsedString = tl.parse(treeString)
		if self.traversalString != parsedString:
			self.traversalString = parsedString
			self.traversalSteps = self.execute(treeString)
			self.traversalInd = 1
			return self.traversalSteps[0]
		else:
			if self.traversalInd == len(self.traversalSteps):
				self.traversalSteps = self.execute(treeString)
				self.traversalInd = 1
				return self.traversalSteps[0]
			else: 
				self.traversalInd += 1
				return self.traversalSteps[self.traversalInd-1]

	def nodesByDepth(self, returnValues=True):
		nodes = [[self.root]]
		vals = [[self.root.value]]
		children = [child for node in nodes[-1] for child in node.children]
		while len(children) != 0:
			nodes.append(children)
			vals.append(map(lambda n: n.value, children))
			children = [child for node in nodes[-1] for child in node.children]

		return vals if returnValues else nodes

class Node:

	def __init__(self, value = None, parent = None):
		self.children = []
		self.value = value
		self.parent = parent
		self.treePosition = "0"




if __name__ == "__main__":
	main()

