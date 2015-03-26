package flock;

import flock.FieldPoint.Pt;
import motion.easing.Cubic;
import motion.easing.Cubic.CubicEaseInOut;
import motion.easing.IEasing;
import motion.easing.Linear;
import motion.easing.Quad;
import util.MathUtil;

/**
 * ...
 * @author Mike Almond - https://github.com/mikedotalmond
 */

 typedef Pt = {
	var x:Float;
	var y:Float;
	var f:Float;
 }

@:allow(flock.FlockTiles)
class FieldPoint {
	
	static inline var Width = 1280;
	static inline var Height = 480;
	static inline var rMax = 2147483647;
	
	var next:Pt;
	var last:Pt;
	var current:Pt;
	var seed:#if js Int#else UInt#end;
	
	function new(seed=1){
		this.seed = seed < 1 ? 1 : (seed >= rMax ? rMax-1 : seed);
		next 	= { x:.0, y:.0, f:.0 };
		last 	= { x:.0, y:.0, f:.0 };
		current = { x:.0, y:.0, f:.0 };
		rndPoint(current);
		rndPoint(next);
	}
	
	function copyPt(to:Pt,from:Pt) {
		to.x = from.x;
		to.y = from.y;
		to.f = from.f;
	}
	
	function rndPoint(pt:Pt) {
		pt.x = rnd() % Width;
		pt.y = rnd() % Height;
		pt.f = (rnd() / rMax);
	}
	
	function rndPointOffset(pt:Pt) {
		
		var w2 = Width / 2;
		var h2 = Height / 2;
		var w25 = Width * 1.25;
		var h5 = Height * .75;
		
		var x,y;
		function newX() x = w2 + fRndOffset() * w25;
		function newY() y = h2 + fRndOffset() * h5;
		
		var dx = .0;
		while (dx < 256 || dx > 512) {
			newX();
			dx = pt.x - x;
			dx = MathUtil.abs(dx);
		}
		
		var dy = .0;
		while (dy < 64 || dy > 200) {
			newY();
			dy = pt.y - y;
			dy = MathUtil.abs(dy);
		}
		
		pt.x = x;
		pt.y = y;
		pt.f = fRnd();
	}
	
	function step(now, dt) { }
	
	inline function rnd() return (seed = MathUtil.rnd(seed));
	inline function fRnd() return rnd() / rMax;
	inline function fRndOffset() return (fRnd() - .5);
}


class EasedPoint extends FieldPoint {
	
	var startTime		:Float = 0;
	var endTime			:Float = 0;
	
	var duration		:Float;
	var maxForce		:Float;
	var ease			:IEasing;
	
	function new(duration = 2.0, maxForce=1.0, ease:IEasing=null, seed=1) {
		super(seed);
		this.duration = duration;
		this.maxForce = maxForce;
		this.ease = ease == null ? Linear.easeNone : ease;
	}
	
	override function step(now, dt) {
		
		if (endTime > 0 && now < endTime) {
			
			var position = ease.calculate((now - startTime) / duration);
			
			current.x = last.x + (next.x - last.x) * position;
			current.y = last.y + (next.y - last.y) * position;
			current.f = last.f + (next.f - last.f) * position;
			
		} else {
			
			// set current as last and get another point to ease to
			current.f *= .25; // reduce force
			copyPt(last, current);
			getNextPoint();
			
			endTime = now + duration;
			startTime = now;
		}
	}
	
	// override to do something other than random position...
	function getNextPoint() {
		
	}
}


class RndPoint extends EasedPoint {
	
	public function new(duration=2.0, maxForce=1.0, ease:IEasing=null, seed=1) {
		super(duration, maxForce, ease, seed);
		rndPoint(current);
		current.f *= maxForce;
		getNextPoint();
	}
	
	override function getNextPoint() {
		rndPointOffset(next);
		next.f *= maxForce;
	}
}