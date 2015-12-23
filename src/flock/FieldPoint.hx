package flock;

import flock.FieldPoint.Pt;
import motion.easing.IEasing;
import motion.easing.Linear;
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

@:allow(flock.FlockSprites)
class FieldPoint {
	
	static inline var Width = 1280;
	static inline var Height = 452;
	static inline var rMax = 0x7fffffff;
	
	var next:Pt;
	var last:Pt;
	var current:Pt;
	var seed:Int;
	
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
		pt.x = (rnd() % (Width * 3)) - Width;
		pt.y = (rnd() % Height) -32;
		pt.f = (rnd() / rMax);
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
		rndPoint(next);
		next.f *= maxForce;
	}
}