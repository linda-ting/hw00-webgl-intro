#version 300 es

// This is a fragment shader. If you've opened this file first, please
// open and read lambert.vert.glsl before reading on.
// Unlike the vertex shader, the fragment shader actually does compute
// the shading of geometry. For every pixel in your program's output
// screen, the fragment shader is run for every bit of geometry that
// particular pixel overlaps. By implicitly interpolating the position
// data passed into the fragment shader by the vertex shader, the fragment shader
// can compute what color to apply to its pixel based on things like vertex
// position, light position, and vertex color.
precision highp float;

uniform vec4 u_Color; // The color with which to render this instance of geometry.
uniform highp int u_Time; // The current time, used for noise input

// These are the interpolated values out of the rasterizer, so you can't know
// their specific values without knowing the vertices that contributed to them
in vec4 fs_Nor;
in vec4 fs_LightVec;
in vec4 fs_Pos;
in vec4 fs_Col;
in vec4 fs_CameraPos;
in float fs_Biome;
in float fs_Height;

out vec4 out_Col; // This is the final output color that you will see on your
                  // screen for the pixel that is currently being processed.

float noise3D(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 244.1))) * 1288.002);
}

float interpNoise3D(float x, float y, float z) {
    int intX = int(floor(x));
    float fractX = fract(x);
    int intY = int(floor(y));
    float fractY = fract(y);
    int intZ = int(floor(z));
    float fractZ = fract(z);

    float v1 = noise3D(vec3(intX, intY, intZ));
    float v2 = noise3D(vec3(intX + 1, intY, intZ));
    float v3 = noise3D(vec3(intX, intY + 1, intZ));
    float v4 = noise3D(vec3(intX + 1, intY + 1, intZ));

    float v5 = noise3D(vec3(intX, intY, intZ + 1));
    float v6 = noise3D(vec3(intX + 1, intY, intZ + 1));
    float v7 = noise3D(vec3(intX, intY + 1, intZ + 1));
    float v8 = noise3D(vec3(intX + 1, intY + 1, intZ + 1));

    float i1 = mix(v1, v2, fractX);
    float i2 = mix(v3, v4, fractX);
    float i3 = mix(v5, v6, fractX);
    float i4 = mix(v7, v8, fractX);

    float i5 = mix(i1, i2, fractY);
    float i6 = mix(i3, i4, fractY);

    return mix(i5, i6, fractZ);
}

float fbm3D(vec3 p) {
    float x = p.x;
    float y = p.y;
    float z = p.z;
    
    float total = 0.;
    float persistence = 0.7;
    int octaves = 4;

    for(int i = 1; i <= octaves; i++) {
        float freq = pow(2.f, float(i));
        float amp = pow(persistence, float(i));
        total += interpNoise3D(x * freq, y * freq, z * freq) * amp;
    }
    return total;
}

vec3 palette(vec3 p) {
  vec3 a = vec3(.8,.7,.6);
  vec3 b = vec3(.5,.5,.4);
  vec3 c = vec3(.3,.2,.7);
  vec3 d = vec3(u_Color);
  float t = fbm3D(p * vec3(0.5) + vec3(sin(float(u_Time) * 0.0005)));
  return a + b * cos(6.28318 * (c * t + d));
}

vec4 fog(vec3 p) {
  float t = fbm3D(p * vec3(0.5) + vec3(float(u_Time) * 0.0005));
  if (t <= 1.0) {
    return vec4(0.0);
  } else if (t <= 1.15) {
    // light fog
    return vec4(0.2);
  }
  // clouds
  return vec4(0.7);
}

vec3 terrainColor(float height, int biome) {
  if (biome != 3) {
    if (height <= 1.61) {
      // deep ocean
      return u_Color.rgb + vec3(.14, -.21,-.18);
    } else if (height <= 1.655) {
      // mid ocean
      return u_Color.rgb;
    } else if (height <= 1.66) {
      // shallow ocean
      return u_Color.rgb + vec3(-.03, .39, -.24);
    }
  }

  if (biome == 1) {
    // temperate
    if (height <= 1.67) {
      return vec3(216.0, 255.0, 144.0) / vec3(255.0);
    } else if (height <= 1.76) {
      return vec3(179.0, 245.0, 118.0) / vec3(255.0);
    }
    return vec3(255.0, 232.0, 206.0) / vec3(255.0);
  } else if (biome == 2) {
    // tundra
    if (height <= 1.67) {
      return vec3(154.0, 181.0, 255.0) / vec3(255.0);
    } else if (height <= 1.705) {
      return vec3(147.0, 239.0, 217.0) / vec3(255.0);
    }
    return vec3(212.0, 243.0, 219.0)/ vec3(255.0);
  } else if (biome == 3) {
    // desert
    if (height <= 1.7) {
      return vec3(230.0, 107.0, 79.0) / vec3(255.0);
    } else if (height <= 1.745) {
      return vec3(255.0, 167.0, 113.0)  / vec3(255.0);
    }
    return vec3(255.0, 204.0, 204.0) / vec3(255.0);
  } else {
    // tropical
    if (height <= 1.67) {
      return vec3(232.0, 250.0, 232.0) / vec3(255.0);
    } else if (height <= 1.75) {
      return vec3(227.0, 198.0, 255.0) / vec3(255.0);
    }
    return vec3(0.0, 165.0, 135.0) / vec3(255.0);
  }
}

void main()
{
  // Material base color (before shading)
  vec4 diffuseColor = fog(fs_Pos.xyz) + vec4(terrainColor(fs_Height, int(fs_Biome)), 1.0);

  // Calculate the diffuse term for Lambert shading
  float diffuseTerm = dot(normalize(fs_Nor), normalize(fs_LightVec));
  // Avoid negative lighting values
  diffuseTerm = clamp(diffuseTerm, 0.f, 1.f);

  // Calculate specular light intensity
  vec4 view = normalize(fs_CameraPos - fs_Pos);
  vec4 sumViewLight = view + fs_LightVec;
  vec4 h = sumViewLight / 2.0;
  float specularTerm = max(pow(dot(h, normalize(fs_Nor)), 30.0), 0.0);

  float ambientTerm = 0.4;
  float lightIntensity = diffuseTerm + ambientTerm;   //Add a small float value to the color multiplier
                                                      //to simulate ambient lighting. This ensures that faces that are not
                                                      //lit by our point light are not completely black.

  // Compute final shaded color
  out_Col = vec4(diffuseColor.rgb * lightIntensity, 1.0) + vec4(vec3(specularTerm), 1.0);
}
