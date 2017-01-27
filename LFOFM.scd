(
var sinwav = {|f,p,a,s, time| (sin((pi*f*time)+p)*a)+s};
var coswav = {|f,p,a,s, time| (cos((pi*f*time)+p)*a)+s};

var sqr = {|time| var tm = time%2; if(tm<1, 1, -1)};
var sqrwav = {|f,p,a,s, time| (sqr.((f*time)+p)*a)+s};

var saw = {|time| var tm = time%2; tm-1};
var sawwav = {|f,p,a,s, time| (saw.((f*time)+p)*a)+s};

var tri = {|time| var tm = time%2; case {tm<0.5} {1-(2*tm)} {tm<1.5} {2-(2*tm)} {tm>=1.5} {2*tm-4}};
var triwav = {|f,p,a,s, time| (tri.((f*time)+p)*a)+s};

var calcStr = "triwav.(1,0,1,triwav.(3,0,sinwav.(sawwav.(5,0,1,0,time),0,0.333333333333,0.0,time),0.0,time),time)";
var createCalcFunc = {|calcString|
    var prepFunc = ("{|sinwav, coswav, sqrwav, sawwav, triwav| {|time|" + calcStr + "}};").interpret;
    prepFunc.(sinwav, coswav, sqrwav, sawwav, triwav);
};
var func = createCalcFunc.(calcStr);
func.(1)
)


(
var tri = {|time| var tm = time%2; case {tm<0.5} {1-(2*tm)} {tm<1.5} {2-(2*tm)} {tm>=1.5} {2*tm-4}};
var triwav = "{|tri, f,p,a,s, time| (tri.((f*time)+p)*a)+s}".interpret;
triwav.(tri, 1, 0, 1, 0, 0.25)

)