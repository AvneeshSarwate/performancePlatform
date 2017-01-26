(
var get = {|a, b| a+b};
"var get = {|a, b| a+b}; get.(5, 6)".interpret;

)

sin(5)

(
var sinwav = {|f,p,a,s, time| (sin((pi*f*time)+p)*a)+s};
var coswav = {|f,p,a,s, time| (cos((pi*f*time)+p)*a)+s};

var sqr = {|time| var tm = time%2; if(tm<1, 1, -1)};
var sqrwav = {|f,p,a,s, time| (sqr.((f*time)+p)*a)+s};

var saw = {|time| var tm = time%2; tm-1};
var sawwav = {|f,p,a,s, time| (saw.((f*time)+p)*a)+s};

var tri = {|time| var tm = time%2; case {tm<0.5} {1-(2*tm)} {tm<1.5} {2-(2*tm)} {tm>=1.5} {2*tm-4}};
var triwav = {|f,p,a,s, time| (tri.((f*time)+p)*a)+s};

sinwav.(1,0,1,0, 0.5)
)


(
var tri = {|time| var tm = time%2; case {tm<0.5} {1-(2*tm)} {tm<1.5} {2-(2*tm)} {tm>=1.5} {2*tm-4}};
tri.(0.25)
)