package sound;

/**
 * Compiletime load and process regions CSV exported from Reaper
 * Builds Array<AudioRegion>
 * 
 * @author Mike Almond | https://github.com/mikedotalmond
 */
@:access(CompileTime)
class SeascapeRegions {
	
    macro public static function parse(path:String):ExprOf<Array<AudioRegion>> {
        return CompileTime.toExpr(parseCSVString(path));
    }
	
	#if macro
		static function parseCSVString(path:String) {
			
			var str:String = CompileTime.loadFileAsString(path);
			
			//0D 0A
			var lines = str.split('\r\n');
			lines.shift(); // remove headers
			if (lines[lines.length - 1].length == 0) lines.pop();  // remove trailing empty newline
			
			var output = [];
			for (line in lines) output.push(parseEntry(line));
			
			return output;
		}
		
		static function parseEntry(line:String):AudioRegion {
			// "R1,,0:01.000,0:22.500,0:21.500"
			// Only care about start and end values, don't bother parsing name or duration
			var values = line.split(",").splice(2, 2);
			return {
				start : toSeconds(values[0]), 
				end	: toSeconds(values[1]),
			}
		}
		
		// mm:ss.millis
		static function toSeconds(time:String):Float {
			var c = time.indexOf(':');
			var m = Std.parseInt(time.substr(0, c));
			var s = Std.parseFloat(time.substr(c + 1));
			return m * 60 + s;
		}
	#end
}