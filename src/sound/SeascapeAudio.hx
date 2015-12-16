package sound;

import hxsignal.Signal;
import js.Error;
import js.html.ArrayBuffer;
import js.html.audio.AudioBuffer;
import js.html.audio.AudioContext;
import js.html.audio.AudioNode;
import tones.AudioBase;
import tones.Samples;

class SeascapeAudio {
	
	public static var regions(default, never):Array<AudioRegion> = SeascapeRegions.parse('res/seascape_regions.csv');
	
	var ready:Signal<Void->Void>;
	var error:Signal<String->Void>;
	
	var context:AudioContext;
	var buffer:AudioBuffer;
	
	public function new() {
		
		context = AudioBase.createContext();
		
		ready = new Signal<Void->Void>();
		error = new Signal<String->Void>();
		
		var audioType =
			if (Samples.canPlayType('audio/ogg')) 'ogg'
			else if (Samples.canPlayType('audio/mp3')) 'mp3'
			else null;
		
		var audioURL = 'audio/seascape.$audioType';
		
		#if debug
		trace('SeascapeAudio - audioType:$audioType, audioURL:$audioURL', regions);
		#end
		
		// start loading the audio
		Samples.loadArrayBuffer(audioURL, onArrayBufferLoaded, onLoadProgress, onError);
	}
	
	
	function onLoadProgress(value:Float) {
		trace('onProgress $value');
	}
	
	
	function onArrayBufferLoaded(buffer:ArrayBuffer) {
		trace('onArrayBufferLoaded');
		// decode shouldn't take too long, but does block execution, so do this when it won't be noticed.
		Samples.decodeArrayBuffer(buffer, context, onDecoded, onError);
	}
	
	
	function onDecoded(buffer:AudioBuffer) {
		trace('buffer ready');
		trace(buffer);
		
		this.buffer = buffer;
		ready.emit();
	}
	
	
	function onError(err:Error) {
		trace('Error loading the AudioBuffer :(');
		trace(err);
		error.emit(err.message);
	}
}


