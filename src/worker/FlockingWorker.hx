package worker;

/**
 * ...
 * @author Mike Almond - https://github.com/mikedotalmond
 */

import js.html.Float32Array;
import net.rezmason.utils.workers.BasicWorker;

import worker.FlockData.FlockInitData;
import worker.FlockData.FlockUpdateData;

import worker.Data.WorkerData;
import worker.FlockingWorker.Boid;

import util.MathUtil;

@:keep
@:final class FlockingWorker extends BasicWorker<WorkerData, Float32Array> {

	public static inline var WIDTH:Float = 1280;
	public static inline var HEIGHT:Float = 500;
	
	public static inline var TURN_SPEED:Float = .035;
	public static inline var GridYOffset = 64;
	
	public static inline var MIN_DIST:Float = 2.5 * 2.5;
	public static inline var MAX_DIST:Float = 16 * 16;
	public static inline var MAX_DX:Float = 16;
	
	// spatial partitioning
	static inline var CellSize = 32;
	static inline var CellCountX = Std.int(1280 / CellSize);
	static inline var CellCountY = Std.int(576 / CellSize);
	static inline var CellCount = CellCountX * CellCountY;
	
	
	static inline var YCount = CellCountX * CellCountY;
	
	
	var count			:Int;
	var dataOffset		:Int;
	var boids			:Boid;
	var drawList		:Float32Array;
	var cells			:Array<Array<Boid>>;
	var screenDensity	:Float;
	
	
	override function process(data:WorkerData):Float32Array {
		switch(data.type) {
			case Data.TYPE_INIT: init(cast data);
			case Data.TYPE_UPDATE: update(cast data);
		}
		return drawList;
	}
	
	
	function init(data:FlockInitData) {
		screenDensity = data.screenDensity;
		if (screenDensity > 1) screenDensity = screenDensity * .5;
		cells = [for (i in 0...CellCount) [] ];
		createBoids(data.count);
	}
	
	static inline var Data_X		:Int = 0;
	static inline var Data_Y		:Int = 1;
	static inline var Data_Scale	:Int = 2;
	static inline var Data_Alpha	:Int = 3;
	
	function createBoids(count:Int) {
		
		this.count 	= count;
		boids 		= null;
		var last 	= null;
		var data 	= [];
		
		var cloneOffset = count * FlockData.TILE_FIELDS;
		var b; var index; var size; var scale; var speed; var turnSpeed;
		
		for (i in 0...count) {
			
			size 			= 1.5 + Math.random(); 
			scale 			= .7 + Math.random() * .2;
			speed 			= .85 + Math.random() * .4;
			turnSpeed 		= TURN_SPEED + TURN_SPEED * (Math.random()) * 1.5;
			
			b 				= new Boid(i, size, scale, speed, turnSpeed);
			
			b.x 			= 64 + Math.random() * (WIDTH-128);
			b.y 			= 64 + Math.random() * 200;
			b.alpha 		= .4 + Math.random() * .2;
			b.angle 		= Math.random() * MathUtil.TWO_PI;
			
			index 						= i * FlockData.TILE_FIELDS;
			data[index + Data_X] 		= b.x;
			data[index + Data_Y] 		= b.y;
			data[index + Data_Scale] 	= b.drawScale = ((b.scale * size / 4.8) * screenDensity);
			data[index + Data_Alpha] 	= b.alpha;
			
			index 						+= cloneOffset;
			data[index + Data_X] 		= b.x;
			data[index + Data_Y] 		= b.y;
			data[index + Data_Scale] 	= .25;
			data[index + Data_Alpha]	= 0.04;// b.alpha * .2;
			
			if (boids == null) boids = b;
			else last.next = b;
			
			b.first = boids;
			last 	= b;
		}
		
		// Add X_DATA_POINTS+Y_DATA_POINTS extra fields for flock data...
		dataOffset 	= data.length;
		data 		= data.concat([for(i in 0...(FlockData.X_DATA_POINTS + FlockData.Y_DATA_POINTS)) .0]);
		
		drawList = new Float32Array(data);
	}
	
	
	function update(data:FlockUpdateData) {
		
		var cloneOffset = count * FlockData.TILE_FIELDS;
		
		var pointForces = data.pointForces;
		var fieldCount = Std.int(pointForces.length / 3);
		
		var d = drawList;
		var c = cells;
		
		// empty cells
		for (i in 0...CellCount) {
			untyped __js__('c[i].length = 0'); // set length on array is ok in js...
		}
		
		var b = boids;
		var cellSize = 32;
		var offset = dataOffset;
		
		var bX, bY, bXi, bYi, tmpA, tmpB;
		var absV = .0;
		var end = FlockData.X_DATA_POINTS + FlockData.Y_DATA_POINTS;
		
		// reset x/y data
		for (j in offset...end) d[j] = .0;
		
		while (b != null) {
			// partitioning
			bX = b.x; bY = b.y;
			bXi = Std.int(bX / CellSize);
			bYi = Std.int((bY + GridYOffset) / CellSize);
			c[bXi + bYi * CellCountX].push(b);
			
			// flock stats
			absV = MathUtil.abs(b.vy);
			d[offset + Std.int((bX / WIDTH) * FlockData.X_DATA_POINTS)] += absV;
			
			absV = MathUtil.abs(b.vx);
			d[offset + Std.int((bY / HEIGHT) * FlockData.Y_DATA_POINTS) + FlockData.X_DATA_POINTS] += absV;
			
			b = b.next;
		}
		
		var scaleFactor = data.scaleFactor;
		
		b = boids;
		
		var index;
		var yScale;
		var bx, by;
		
		while (b != null) {
			
			bx = b.x; by = b.y;
			
			// limit 'thinking' to n% of the time for more.. unpredictable movement. think more near water.
			if (Math.random() > .666 && b.y < 400) {
				b.step();
			} else {
				bXi = Std.int(bx / cellSize);
				bYi = Std.int((by + GridYOffset) / cellSize);
				getClosest(b, c[bXi + bYi * CellCountX]);
				b.update(fieldCount, pointForces);
			}
			
			b.closest = null;
			b.closestDist = 0;
			
			index = b.index * FlockData.TILE_FIELDS;
			
			var alpha = b.alpha - (b.rotationChange);
			if (alpha < 0.01) alpha = b.alpha * (1 - alpha) * 1.333;
			d[index + Data_Alpha] = alpha;
			
			d[index + Data_X] = bx;
			d[index + Data_Y] = by;
			
			tmpA = b.drawScale;
			tmpB = tmpA / scaleFactor;
			d[index + Data_Scale] = MathUtil.min(tmpA, tmpB);
			
			// 'reflection' clones			
			index += cloneOffset;
			d[index + Data_X] = bx;
			d[index + Data_Y] = 512 + (HEIGHT - b.y) * .15; 
			
			yScale = 1 - (by / HEIGHT); // x pos
			d[index + Data_Scale] = b.scale + b.scale * yScale * .7; // y pos
			
			d[index + Data_Alpha] = .04 - .03 * yScale;
			
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
				f = (1.0 / (hx * hx + hy * hy));
				f *= f;
				f *= strength;
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
			angle += angleDifference * turnSpeed * (.8 + Math.random() * .2); 
		} else {
			angle -= angleDifference * turnSpeed * (.8 + Math.random() * .2);
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