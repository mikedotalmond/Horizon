package worker;

import openfl.utils.Int32Array;

import worker.BackgroundImageData.BackgroundStripUpdateData;

import net.rezmason.utils.workers.BasicWorker;

import worker.Data.WorkerData;
import worker.BackgroundImageData.BackgroundInitData;
import worker.BackgroundImageData.BackgroundUpdateData;

/**
 * ...
 * @author Mike Almond - https://github.com/mikedotalmond
 */

@:keep
@:final class BackgroundImageWorker extends BasicWorker<WorkerData, Int32Array> {
	
	#if html5
	static inline var rRange = 10;
	#else
	static inline var rRange = 5;
	#end
	
	// random noise amount
	static inline var hrRange = rRange>>1;
	
	// array of source images
	var sources:Array<Int32Array>;
	
	// one image, sliced into horizontal strips of Int32Array
	var outData:Array<Int32Array>;
	
	var initComplete:Int32Array;
	var updateComplete:Int32Array;
	
	override function process(data:WorkerData):Int32Array {		
		return switch(data.type) {
			case BackgroundImageData.TYPE_STRIP_UPDATE : getStrip(cast data);
			case Data.TYPE_UPDATE : build(cast data);
			case Data.TYPE_INIT	: init(cast data); 
			case _ : null;
		}
	}
	
	
	function init(data:BackgroundInitData) {
		sources = data.sources;
		
		outData = []; 
		for (i in 0...BackgroundImageData.Height) {
			var d = [];
			for (j in 0...BackgroundImageData.Width) d[j] = 0;			
			outData[i] = new Int32Array(d);
		}
		
		// sent when update completes... can't send null/no data - has to match defined output type (Int32Array)
		initComplete = new Int32Array([0]);
		updateComplete = new Int32Array([1]);
		
		return initComplete;
	}	
	
	
	function build(data:BackgroundUpdateData) {
		
		var imageData = sources[data.index];
		
		var noiseSeed = data.seed;		
		if (noiseSeed < 1) noiseSeed = 1;
		else if (noiseSeed >= 2147483647) noiseSeed = 2147483646;
		
		// using UInt here adds a fair bit of stuff to the js output for each rnd() call... range checking. UInt is needed for cpp targets though.
		#if js
		inline function rnd() return noiseSeed = (noiseSeed * 16807) % 2147483647;
		#else
		inline function rnd():UInt return noiseSeed = (noiseSeed * 16807) % 2147483647;
		#end
		
		// vertical slices...
		var sliceCount = 3 + (rnd() % 3);
		var stripWidth = Std.int(BackgroundImageData.Width / sliceCount);
		
		var srcStrips = [ for (i in 0...sliceCount) 0|((i * stripWidth) + (rnd() % stripWidth)) ];
		
		var dataY;
		var xSlicePosition, yOffset, f, f2;
		var x, y, sliceIndex, sliceA, sliceB, r, g, b;
		// for every pixel...
		for (i in 0...BackgroundImageData.PixelCount) {
			
			x 				= (i % BackgroundImageData.Width);
			xSlicePosition 	= x / BackgroundImageData.Width * (sliceCount - 1);
			sliceIndex 		= Std.int(xSlicePosition);
			
			y 				= Std.int(i / BackgroundImageData.Width);			
			yOffset			= y * BackgroundImageData.Width;
			
			sliceA 			= imageData[yOffset + srcStrips[sliceIndex]];
			sliceB 			= imageData[yOffset + srcStrips[sliceIndex + 1]];
			
			// rgb mix - linearly interpolate between slices and add some noise
			f2 = xSlicePosition - sliceIndex;
			f = (1.0 - f2);
			
			r = Std.int(((sliceA >> 16)	& 0xff) * f);
			g = Std.int(((sliceA >> 8)	& 0xff) * f);
			b = Std.int((sliceA			& 0xff) * f);
			//
			r += Std.int(((sliceB >> 16)& 0xff) * f2);
			g += Std.int(((sliceB >> 8) & 0xff) * f2);
			b += Std.int((sliceB		& 0xff) * f2);
			
			// add noise
			r += (rnd() % rRange) - hrRange;
			g += (rnd() % rRange) - hrRange;
			b += (rnd() % rRange) - hrRange;
			
			// clamp
			r = (r<0?0:r>255?255:r);
			g = (g<0?0:g>255?255:g);
			b = (b<0?0:b>255?255:b);
			
			//NOTE: Android target complains (invalid-initialization-of-non-const-reference) if/when trying to access outData[y][x] directly - so created the dataY intermediate
			dataY = outData[y];			
			#if html5
			dataY[x] = ((r << 24) | (g << 16) | b << 8) | 0xff;
			#else
			dataY[x] = 0xff000000 | (r << 16) | (g << 8) | b;
			#end
		}
		
		return updateComplete;
	}
	
	inline function getStrip(data:BackgroundStripUpdateData):Int32Array return outData[data.y];
}