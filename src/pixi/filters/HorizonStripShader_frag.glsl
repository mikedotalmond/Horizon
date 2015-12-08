#ifdef GL_ES
precision mediump float;
precision mediump int;
#else
precision highp float;
#endif

#define SLICE_COUNT 6.0;

uniform sampler2D textureA;
uniform sampler2D textureB;

uniform vec2 seeds;
uniform float position;

uniform vec4 stripsA;
uniform vec3 stripsB;

uniform vec3 yOffsets; // x = amount, y=centre, z=angle/skew

//varying vec4 vertColor;
varying vec2 vTextureCoord;

float rnd(vec2 x)
{
    return fract(sin(dot(x.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

void main(void) {
  
  float xSlicePosition = vTextureCoord.x * SLICE_COUNT;
  int sliceIndex = int(xSlicePosition);
  
  // prandom numbers for this pixel
  float rX = rnd(seeds.x * vTextureCoord);
  float rY = rnd(seeds.y * vTextureCoord);
  
  // get y position, and add offsets to scale and position some Y noise
  float y = vTextureCoord.y + (rY - yOffsets.z) * vTextureCoord.y * (fract(vTextureCoord.x) - yOffsets.y) * yOffsets.x;
  
  vec2 sliceACoord = vec2(0, y);
  vec2 sliceBCoord = vec2(0, y);
  
  if(sliceIndex == 0) {
	sliceACoord.s = stripsA[0];
	sliceBCoord.s = stripsA[1];
  } else if(sliceIndex == 1){
	sliceACoord.s = stripsA[1];
	sliceBCoord.s = stripsA[2];
  } else if(sliceIndex == 2){
	sliceACoord.s = stripsA[2];
	sliceBCoord.s = stripsA[3];
  } else if(sliceIndex == 3){
	sliceACoord.s = stripsA[3];
	sliceBCoord.s = stripsB[0];
  } else if(sliceIndex == 4){
	sliceACoord.s = stripsB[0];
	sliceBCoord.s = stripsB[1];
  } else { //if(sliceIndex == 5){
	sliceACoord.s = stripsB[1];
	sliceBCoord.s = stripsB[2];
  }
 
  // lerp between the two sampling positions
  float f2 = xSlicePosition - float(sliceIndex);
  
  vec4 mixA = ( 1.0 - f2 ) * texture2D(textureA, sliceACoord) + f2 * texture2D(textureA, sliceBCoord);
  vec4 mixB = ( 1.0 - f2 ) * texture2D(textureB, sliceACoord) + f2 * texture2D(textureB, sliceBCoord);
  
  
  vec4 mix = position * mixA + (1.0-position) * mixB;
  
  // add noise (monochromatic)
  mix += (rX - 0.5) * .06; // noiseAmt
  
  // output
  gl_FragColor = mix;
}
