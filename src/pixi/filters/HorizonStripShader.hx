package pixi.filters;

import js.html.Float32Array;
import pixi.core.textures.Texture;
import pixi.core.renderers.webgl.filters.AbstractFilter;

/**
 * ...
 * @author Mike Almond | https://github.com/mikedotalmond
 */
class HorizonStripShader extends AbstractFilter {

	public function new(textureA:Texture, textureB:Texture) {
		super(null, CompileTime.readFile('pixi/filters/HorizonStripShader_frag.glsl'), {
			textureA:     	{ type: 'sampler2D', value: textureA },
			textureB:     	{ type: 'sampler2D', value: textureB },
            position:     	{ type: 'f', value: .5 },
            seeds:     		{ type: 'v2', value: { x: .345345, y: .34532 } },
			stripsA:		{ type: 'v4', value: { x: 0, y: 0.1, z:0.2, w:0.3 } },
			stripsB:		{ type: 'v3', value: { x: .4, y: .5, z:.6 } },
			yOffsets:		{ type: 'v3', value: { x: 0, y: 0 , z:0 } },
		});
	}
	
	public function reseed(x:Float, y:Float) {
		uniforms.seeds.value.x = x;
		uniforms.seeds.value.y = y;
	}
	
	public function setYOffsetData(amount:Float, centre:Float, angle:Float){
		uniforms.yOffsets.value.x = amount;
		uniforms.yOffsets.value.y = centre;
		uniforms.yOffsets.value.z = angle;
	}
	
	public function setStrips(values:Float32Array) {
		var v = uniforms.stripsA.value;
		v.x = values[0];
		v.y = values[1];
		v.z = values[2];
		v.w = values[3];
		v = uniforms.stripsB.value;
		v.x = values[4];
		v.y = values[5];
		v.z = values[6];  	
	}
	
	public var fadePosition(get, set):Float;
	inline function get_fadePosition() return uniforms.position.value;
	inline function set_fadePosition(value:Float) return uniforms.position.value = value;
	
	public var textureA(get,set):Texture;
	inline function get_textureA() return uniforms.texture.value;
	inline function set_textureA(value:Texture) return uniforms.texture.value = value;
	
	public var textureB(get,set):Texture;
	inline function get_textureB() return uniforms.texture.value;
	inline function set_textureB(value:Texture) return uniforms.texture.value = value;
	
}