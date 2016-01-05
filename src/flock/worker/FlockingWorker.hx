package flock.worker;

/**
 * ...
 * @author Mike Almond - https://github.com/mikedotalmond
 */

import js.html.Float32Array;
import net.rezmason.utils.workers.BasicWorker;

import flock.worker.*;
import flock.worker.types.*;

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
			case WorkerDataType.INIT: init(cast data);
			case WorkerDataType.UPDATE: update(cast data);
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
		
		var cloneOffset = count * FlockDataFields.COUNT;
		var b; var index; var size; var scale; var speed; var turnSpeed;
		
		for (i in 0...count) {
			
			size = 1.25 + Math.random(); 
			scale = (1) + Math.random() * .10;
			speed = (2/3) + Math.random() * (1/3);
			turnSpeed = TURN_SPEED + TURN_SPEED * Math.random();// * (2 / 3);
			
			b = new Boid(i, size, scale, speed, turnSpeed);
			
			b.x = 64 + Math.random() * (WIDTH-128);
			b.y = 64 + Math.random() * 200;
			b.alpha = .4 + Math.random() * .2;
			b.angle = Math.random() * MathUtil.TWO_PI;
			
			index = i * FlockDataFields.COUNT;
			data[index + FlockDataFields.DATA_X] = b.x;
			data[index + FlockDataFields.DATA_Y] = b.y;
			data[index + FlockDataFields.DATA_SCALE] = b.drawScale = (b.scale * size / 5);
			data[index + FlockDataFields.DATA_ALPHA] = b.alpha;
			
			index += cloneOffset;
			data[index + FlockDataFields.DATA_X] = b.x;
			data[index + FlockDataFields.DATA_Y] = b.y;
			data[index + FlockDataFields.DATA_SCALE] = .25;
			data[index + FlockDataFields.DATA_ALPHA] = 0.04;// b.alpha * .2;
			
			if (boids == null) boids = b;
			else last.next = b;
			
			b.first = boids;
			last = b;
		}
		
		//
		drawList = new Float32Array(data);
	}
	
	
	function update(data:FlockUpdateData) {
		
		var dScale = data.drawScale;
		dScale = dScale < .5 ? .5 : dScale;
		
		var cloneOffset = count * FlockDataFields.COUNT;
		
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
			if (b.y < 400 && Math.random() > .75) {
				b.step();
			} else {
				bXi = Std.int(bx / CellSize);
				bYi = Std.int((by + GridYOffset) / CellSize);
				getClosest(b, c[bXi + bYi * CellCountX]);
				b.update(fieldCount, pointForces);
			}
			
			b.closest = null;
			b.closestDist = 0;
			
			index = b.index * FlockDataFields.COUNT;
			
			var alpha = b.alpha - (b.rotationChange);
			if (alpha < 0.01) alpha = b.alpha * (1 - alpha) * 1.333;
			d[index + FlockDataFields.DATA_ALPHA] = alpha;
			
			d[index + FlockDataFields.DATA_X] = bx;
			d[index + FlockDataFields.DATA_Y] = by;
			d[index + FlockDataFields.DATA_SCALE] = b.drawScale/dScale;
			
			// 'reflection' clones			
			index += cloneOffset;
			d[index + FlockDataFields.DATA_X] = bx;
			d[index + FlockDataFields.DATA_Y] = 512 + (HEIGHT - b.y) * .15; 
			
			yScale = 1 - (by / HEIGHT); // x pos
			d[index + FlockDataFields.DATA_SCALE] = (b.scale + b.scale * yScale * .7) / dScale; // y pos
			
			d[index + FlockDataFields.DATA_ALPHA] = 0.03 - .03 * yScale;
			
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

