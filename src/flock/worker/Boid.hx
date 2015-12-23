package flock.worker;

import js.html.Float32Array;
import util.MathUtil;

/**
 * ...
 * @author Mike Almond | https://github.com/mikedotalmond
 */
@:final class Boid {
	
	public var index:Int;
	
	public var x:Float;
	public var y:Float;
	public var haveTarget:Bool=true;
	
	public var vx:Float;
	public var vy:Float;
	
	public var angle:Float;
	public var scale:Float;
	public var drawScale:Float;
	public var alpha:Float;
	
	public var sizeSq:Float;
	public var speed:Float;
	
	public var next	:Boid;
	public var first:Boid;
	public var closest:Boid;
	public var closestDist:Float = .0;
	public var rotationChange:Float = .0;
	
	var turnSpeed:Float;
	
	public function new(index:Int, size:Float, scale:Float, speed:Float, turnSpeed:Float) {
		
		this.index = index;
		this.scale = scale;
		this.speed = speed;
		this.turnSpeed = turnSpeed;
		
		x =	y = vx = vy = angle = .0;
		
		var scaled = size * scale;
		sizeSq = scaled * scaled;
	}
	
	
	public function update(fieldCount:Int, pointForces:Float32Array) {
	
		var strength = 0.0;
		var vxHeading = .0;
		var vyHeading = .0;
		var f = .0;
		var hx = .0;
		var hy = .0;
		var n = fieldCount;
		
		var j;
		for (i in 0...n) {			
			j = i * 3;	
			
			// split into groups for filds to act on 
			// (0...fieldCount) by index - own group gets more force from the associated field, other groups get less
			var modField = j == ((index % fieldCount) * 3);
			
			strength = pointForces[j + 2] * (modField?1:.125);
			if (strength != 0) {
				hx = (pointForces[j] - x);
				hy = (pointForces[j + 1] - y);
				f = 1.0 - ((hx * hx + hy * hy) / 13107200);//2560*2560*2
				f *= strength;
				f /= sizeSq;
				vxHeading += hx * f;
				vyHeading += hy * f;
			}
		}
		
		var dxClosest, dyClosest, distClosest=.0;
		
		if (closest == null) {
			dxClosest = FlockingWorker.MAX_DX * 2 * (Math.random() - .5);
			dyClosest = FlockingWorker.MAX_DX * 2 * (Math.random() - .5);
			distClosest = FlockingWorker.MAX_DIST;
		} else {
			dxClosest = closest.x - x;
			dyClosest = closest.y - y;
			distClosest = closest.closestDist;
		}
		
		var normClosest = dxClosest * dxClosest + dyClosest * dyClosest;
		var vxClosest 	= (dxClosest / normClosest);
		var vyClosest 	= (dyClosest / normClosest);
		
		var vxAverage, vyAverage;
		
		if (distClosest >= FlockingWorker.MAX_DIST) {
			vxAverage = vxClosest;
			vyAverage = vyClosest;
		} else if (distClosest < FlockingWorker.MIN_DIST) {
			vxAverage = -vxClosest; // avoid
			vyAverage = -vyClosest;
		} else {
			vxAverage = vxHeading;
			vyAverage = vyHeading;
		}
		
		// keep off the bottom...
		if (y > 488) vyAverage -= .1; 
		
		var normAverage = Math.sqrt(vxAverage * vxAverage + vyAverage * vyAverage);
		vxAverage = vxAverage / normAverage;
		vyAverage = vyAverage / normAverage;
		
		var angleDifference;
		var crossProduct = vx * vyAverage - vy * vxAverage;
		
		if (vx * vxAverage + vy * vyAverage > 0) {
			angleDifference = Math.asin(crossProduct);	
		} else {
			angleDifference = MathUtil.PI - Math.asin(crossProduct);
		}
		
		// abs
		angleDifference = angleDifference < 0 ? -angleDifference : angleDifference;
		
		if (crossProduct > 0) {
			angle += angleDifference * turnSpeed;
		} else {
			angle -= angleDifference * turnSpeed;
		}
		
		vy = Math.sin(angle);
		vx = Math.cos(angle);
		
		rotationChange = angleDifference * MathUtil.iTWO_PI;
		
		step();
	}
	
	inline public function step():Void {
		x += vx * speed;
		y += vy * speed;
		
		if (x > FlockingWorker.WIDTH) x -= FlockingWorker.WIDTH;
		else if (x < 0) x += FlockingWorker.WIDTH;
		
		if (y < -FlockingWorker.GridYOffset || y >= FlockingWorker.HEIGHT) {
			y = -FlockingWorker.GridYOffset / 2;
			x = Math.random() * FlockingWorker.WIDTH;
		}
	}
}