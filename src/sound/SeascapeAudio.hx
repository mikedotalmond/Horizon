package sound;

import haxe.xml.Check.Attrib;
import hxsignal.Signal;
import js.Error;
import js.html.ArrayBuffer;
import js.html.audio.AudioBuffer;
import js.html.audio.AudioBufferSourceNode;
import js.html.audio.AudioContext;
import js.html.audio.AudioNode;
import tones.AudioBase;
import tones.Samples;

class SeascapeAudio {
	
	public static var regions(default, never):Array<AudioRegion> = SeascapeRegions.parse('res/seascape_regions.csv');
	
	var ready:Signal<Void->Void>;
	var error:Signal<String->Void>;
	var loadProgress:Signal<Float->Void>;
	var bufferLoaded:Signal<Void->Void>;
	
	var context:AudioContext;
	var arrayBuffer:ArrayBuffer;
	var audioBuffer:AudioBuffer;
	var samples:Samples;
	var activeRegions:Map<Int, Int>;
	
	public var isReady(default, null):Bool;
	
	public function new() {
		
		isReady = false;
		
		context = AudioBase.createContext();
		samples = new Samples(context);
		samples.itemBegin.connect(onItemBegin);
		samples.itemRelease.connect(onItemRelease);
		samples.itemEnd.connect(onItemEnd);
		samples.timedEvent.connect(onTimedEvent);
		activeRegions = new Map<Int,Int>();
		
		ready = new Signal<Void->Void>();
		error = new Signal<String->Void>();
		loadProgress = new Signal<Float->Void>();
		bufferLoaded = new Signal<Void->Void>();
	}
	
	
	public function loadBuffer() {
		var audioType =
			if (Samples.canPlayType('audio/ogg')) 'ogg'
			else if (Samples.canPlayType('audio/mp3')) 'mp3'
			else null;
		
		var audioURL = 'audio/seascape.$audioType';
		
		#if debug
		trace('SeascapeAudio - audioType:$audioType, audioURL:$audioURL', regions);
		#end
		
		Samples.loadArrayBuffer(audioURL, onArrayBufferLoaded, onLoadProgress, onError);
	}
	
	
	public function decodeBuffer() {
		// decode shouldn't take too long, but does block execution, so do this when it won't be noticed.
		Samples.decodeArrayBuffer(arrayBuffer, context, onDecoded, onError);
	}
	
	
	function onItemBegin(id:Int, time:Float) {
		
		var item = samples.activeItems.get(id);
		var region = regions[activeRegions.get(id)];
		
		var rTime = region.duration - item.release;
		if (rTime < samples.sampleTime) rTime = samples.sampleTime;
		
		samples.doRelease(id, time + rTime);
	}
	
	function onItemRelease(id:Int, time:Float) {
	}
	
	function onItemEnd(id:Int) {
		activeRegions.remove(id);
	}
	
	function onTimedEvent(id:Int, time:Float) {
		
	}
	
	function playRegion(index:Int, volume:Float, attack:Float, release:Float, delayBy:Float):Int {
		
		var region = regions[index];
		
		samples.volume = volume;
		samples.attack = attack;
		samples.release = release;
		samples.offset = region.start;
		samples.duration = region.duration;
		
		var id = samples.playSample(null, delayBy, false);
		
		activeRegions.set(id, index);
		
		return id;
	}
	
	
	
	function onLoadProgress(value:Float) {
		trace('onProgress $value');
		loadProgress.emit(value);
	}
	
	
	function onArrayBufferLoaded(buffer:ArrayBuffer) {
		trace('onArrayBufferLoaded');
		arrayBuffer = buffer;
		bufferLoaded.emit();
	}
	
	
	function onDecoded(buffer:AudioBuffer) {
		trace('buffer ready');		
		audioBuffer = buffer;
		samples.buffer = buffer;
		isReady = true;
		ready.emit();
	}
	
	
	function onError(err:Error) {
		trace('Error loading the AudioBuffer :(');
		trace(err);
		isReady = false;
		error.emit(err.message);
	}
}


