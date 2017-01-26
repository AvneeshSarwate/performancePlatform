# SIMPLE EXAMPLES
# t = Tri()
# sw = Saw(5)
# s1 = t + (Tri(3)*Sin(freq=sw)) / 3.0
# s2 = (Tri(3)*Saw(5))


class Wave(object):

	def __init__(self, freq=1, phase=1, amp=1, shift=0):
		self.freq = freq
		self.phase = phase
		self.amp = amp
		self.shift = shift
		self.waveName = "PARENT"

	def __str__(self):
		valArgs = [self.freq, self.phase, self.amp, self.shift]
		return self.waveName + ".(" + ",".join(map(str, valArgs)) + ")"

	def __mul__(self, other):
		if type(other) is int or type(other) is float or issubclass(type(other),  Wave):
			self.amp = 0 if other == 0 or self.amp == 0 else self.amp * other
			self.shift = 0 if other == 0 or self.shift == 0 else self.shift * other
			return self
		else:
			raise NotImplementedError

	def __rmul__(self, other):
		if type(other) is int or type(other) is float or issubclass(type(other),  Wave):
			self.amp = 0 if other == 0 else self.amp * other
			self.shift = 0 if other == 0 else self.shift * other
			return self
		else:
			raise NotImplementedError

	def __div__(self, other):
		if other == 0:
			raise ValueError("Can't divide by 0")
		if type(other) is int or type(other) is float or issubclass(type(other),  Wave):
			self.amp = self.amp / other
			self.shift = self.shift / other
			return self
		else:
			raise NotImplementedError

	def __add__(self, other):
		if type(other) is int or type(other) is float or issubclass(type(other),  Wave):
			self.shift = self.shift + other
			return self
		else:
			raise NotImplementedError

	def __radd__(self, other):
		if type(other) is int or type(other) is float or issubclass(type(other),  Wave):
			self.shift = self.shift + other
			return self
		else:
			raise NotImplementedError

	def __sub__(self, other):
		if type(other) is int or type(other) is float or issubclass(type(other),  Wave):
			self.shift = self.shift - other
			return self
		else:
			raise NotImplementedError


class Sin(Wave):
	def __init__(self, freq=1, phase=1, amp=1, shift=0):
		super(Sin, self).__init__(freq, phase, amp, shift)
		self.waveName = "sinwav"


class Cos(Wave):
	def __init__(self, freq=1, phase=1, amp=1, shift=0):
		super(Cos, self).__init__(freq, phase, amp, shift)
		self.waveName = "coswav"


class Tri(Wave):
	def __init__(self, freq=1, phase=1, amp=1, shift=0):
		super(Tri, self).__init__(freq, phase, amp, shift)
		self.waveName = "triwav"


class Sqr(Wave):
	def __init__(self, freq=1, phase=1, amp=1, shift=0):
		super(Sqr, self).__init__(freq, phase, amp, shift)
		self.waveName = "sqrwav"


class Saw(Wave):
	def __init__(self, freq=1, phase=1, amp=1, shift=0):
		super(Saw, self).__init__(freq, phase, amp, shift)
		self.waveName = "sawwav"

# renaming ideas
# sin cos sqr tri saw
# sn  cs  sq  tr  sw
# s   c   q   t   w 
# freq, phase, amp, shift -> freq, amp, shift, phase : anticipated most common use order
# freq, phase, amp, shift -> f, p, a, s : to make code more readable?