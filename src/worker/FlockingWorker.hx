package worker;

/**
 * ...
 * @author Mike Almond - https://github.com/mikedotalmond
 */

import js.html.Float32Array;
import net.rezmason.utils.workers.BasicWorker;

import worker.FlockData;
import worker.FlockData.FlockInitData;
import worker.FlockData.FlockUpdateData;

import worker.Data.WorkerData;
import worker.FlockingWorker.Boid;

import util.MathUtil;

@:keep
@:final class FlockingWorker extends BasicWorker<WorkerData, Float32Array> {

	public static inline var WIDTH:Float = 1280;
	public static inline var HEIGHT:Float = 500;
	
	public static inline var TURN_SPEED:Float = .01;
	public static inline var GridYOffset = 64;
	
	public static inline var MIN_DIST:Float = 2*2;
	public static inline var MAX_DIST:Float = 32 * 32;
	public static inline var MAX_DX:Float = 16;
	
	
	// spatial partitioning
	static inline var CellSize = 32;
	static inline var CellCountX = Std.int(1280 / CellSize);
	static inline var CellCountY = Std.int(576 / CellSize);
	static inline var CellCount = CellCountX * CellCountY;
	
	static inline var YCount = CellCountX * CellCountY;
	
	
	var count:Int;
	var dataOffset:Int;
	var boids:Boid;
	var drawList:Float32Array;
	var cells:Array<Array<Boid>>;
	
	override function process(data:WorkerData):Float32Array {
		switch(data.type) {
			case Data.TYPE_INIT: init(cast data);
			case Data.TYPE_UPDATE: update(cast data);
		}
		return drawList;
	}
	
	
	function init(data:FlockInitData) {
		cells = [for (i in 0...CellCount) [] ];
		createBoids(data.count);
	}
	
	function createBoids(count:Int) {
		
		this.count 	= count;
		boids 		= null;
		var last 	= null;
		var data 	= [];
		
		var cloneOffset = count * FlockData.FIELD_COUNT;
		var b; var index; var size; var scale; var speed; var turnSpeed;
		
		for (i in 0...count) {
			
			size = 1.5 + Math.random(); 
			scale = (2/3) + Math.random() * .25;
			speed = (2/3) + Math.random() * (2/3);
			turnSpeed = TURN_SPEED + TURN_SPEED * Math.random();// * (2 / 3);
			
			b = new Boid(i, size, scale, speed, turnSpeed);
			
			b.x = 64 + Math.random() * (WIDTH-128);
			b.y = 64 + Math.random() * 200;
			b.alpha = .4 + Math.random() * .2;
			b.angle = Math.random() * MathUtil.TWO_PI;
			
			index = i * FlockData.FIELD_COUNT;
			data[index + FlockData.DATA_X] = b.x;
			data[index + FlockData.DATA_Y] = b.y;
			data[index + FlockData.DATA_SCALE] = b.drawScale = (b.scale * size / 5);
			data[index + FlockData.DATA_ALPHA] = b.alpha;
			
			index += cloneOffset;
			data[index + FlockData.DATA_X] = b.x;
			data[index + FlockData.DATA_Y] = b.y;
			data[index + FlockData.DATA_SCALE] = .25;
			data[index + FlockData.DATA_ALPHA] = 0.04;// b.alpha * .2;
			
			if (boids == null) boids = b;
			else last.next = b;
			
			b.first = boids;
			last = b;
		}
		
		//
		drawList = new Float32Array(data);
	}
	
	
	function update(data:FlockUpdateData) {
		
		var cloneOffset = count * FlockData.FIELD_COUNT;
		
		var pointForces = data.pointForces;
		var fieldCount = Std.int(pointForces.length / 3);
		
		var d = drawList;
		var c = cells;
		
		// empty cells
		for (i in 0...CellCount) {
			untyped __js__('c[i].length = 0'); // set length on array is ok in js...
		}
		
		var b = boids;
		
		var absV = .0;
		var bX, bY, bXi, bYi, tmpA, tmpB;
		
		while (b != null) {
			// partitioning
			bX = b.x; bY = b.y;
			bXi = Std.int(bX / CellSize);
			bYi = Std.int((bY + GridYOffset) / CellSize);
			c[bXi + bYi * CellCountX].push(b);
			b = b.next;
		}
		
		b = boids;
		
		var index;
		var yScale;
		var bx, by;
		
		while (b != null) {
			
			bx = b.x; by = b.y;
			
			// limit boid 'thinking' for more.. unpredictable movement. think more near water.
			if (b.y < 400 && Math.random() > .95) {
				b.step();
			} else {
				bXi = Std.int(bx / CellSize);
				bYi = Std.int((by + GridYOffset) / CellSize);
				getClosest(b, c[bXi + bYi * CellCountX]);
				b.update(fieldCount, pointForces);
			}
			
			b.closest = null;
			b.closestDist = 0;
			
			index = b.index * FlockData.FIELD_COUNT;
			
			var alpha = b.alpha - (b.rotationChange);
			if (alpha < 0.01) alpha = b.alpha * (1 - alpha) * 1.333;
			d[index + FlockData.DATA_ALPHA] = alpha;
			
			d[index + FlockData.DATA_X] = bx;
			d[index + FlockData.DATA_Y] = by;
			d[index + FlockData.DATA_SCALE] = b.drawScale;
			
			// 'reflection' clones			
			index += cloneOffset;
			d[index + FlockData.DATA_X] = bx;
			d[index + FlockData.DATA_Y] = 512 + (HEIGHT - b.y) * .15; 
			
			yScale = 1 - (by / HEIGHT); // x pos
			d[index + FlockData.DATA_SCALE] = b.scale + b.scale * yScale * .7; // y pos
			
			d[index + FlockData.DATA_ALPHA] = 0.03 - .03 * yScale;
			
			b = b.next;
		}
	}
	
	
	inline function getClosest(target:Boid, boids:Array<Boid>) {
		var tY = target.y;
		var tX = target.x;
		var dx, dy, d;
		var dist = Math.POSITIVE_INFINITY;
		var closest = null;
		var b = boids;
		for(boid in boids) {
			if (target != boid) {
				dx = boid.x - tX;
				dy = boid.y - tY;
				d = dx * dx + dy * dy - boid.sizeSq;
				if (d < dist) {
					dist = d;
					closest = boid;
					closest.closestDist = dist;
				}
			}
		}
		target.closest = closest;
	}	
}



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
			strength = pointForces[j + 2];
			if (strength != 0) {
				hx = (pointForces[j] - x);
				hy = (pointForces[j + 1] - y);
				f = ((hx * hx + hy * hy) / 13107200);//2560*2560*2
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
			angle += angleDifference * turnSpeed;// * (.9 + Math.random() * .1); 
		} else {
			angle -= angleDifference * turnSpeed;// * (.9 + Math.random() * .1);
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