#version 300 es

//This is a vertex shader. While it is called a "shader" due to outdated conventions, this file
//is used to apply matrix transformations to the arrays of vertex data passed to it.
//Since this code is run on your GPU, each vertex is transformed simultaneously.
//If it were run on your CPU, each vertex would have to be processed in a FOR loop, one at a time.
//This simultaneous transformation allows your program to run much faster, especially when rendering
//geometry with millions of vertices.

uniform mat4 u_Model;       // The matrix that defines the transformation of the
                            // object we're rendering. In this assignment,
                            // this will be the result of traversing your scene graph.

uniform mat4 u_ModelInvTr;  // The inverse transpose of the model matrix.
                            // This allows us to transform the object's normals properly
                            // if the object has been non-uniformly scaled.

uniform mat4 u_ViewProj;    // The matrix that defines the camera's transformation.
                            // We've written a static matrix for you to use for HW2,
                            // but in HW3 you'll have to generate one yourself

uniform highp int u_Time;   // The current time, used for noise input

uniform highp int u_Temp;   // The user's input temperature

uniform highp int u_Precip; // The user's input precipitation

in vec4 vs_Pos;             // The array of vertex positions passed to the shader

in vec4 vs_Nor;             // The array of vertex normals passed to the shader

in vec4 vs_Col;             // The array of vertex colors passed to the shader.

out vec4 fs_Nor;            // The array of normals that has been transformed by u_ModelInvTr. This is implicitly passed to the fragment shader.
out vec4 fs_LightVec;       // The direction in which our virtual light lies, relative to each vertex. This is implicitly passed to the fragment shader.
out vec4 fs_Col;            // The color of each vertex. This is implicitly passed to the fragment shader.
out vec4 fs_Pos;
out vec4 fs_CameraPos;
out float fs_Biome;
out float fs_Height;

vec4 lightPos = vec4(-5, -5, 4, 1); //The position of our virtual light, which is used to compute the shading of
                                        //the geometry in the fragment shader.

float easeInOutQuart(float t) {
  if (t < 0.5) {
    return 8.0 * t * t * t * t;
  }
  return 1.0 - pow(-2.0 * t + 2.0, 4.0) / 2.0;
}

float parabola(float x) {
  float t = fract(x);
  return pow(4.0 * t * (1.0 - t), 2.0);
}

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
  p *= 0.75;
  float x = p.x;
  float y = p.y;
  float z = p.z;
  float total = 0.;

  float persistence = 0.72;
  int octaves = 4;

  for(int i = 1; i <= octaves; i++) {
    float freq = pow(2.f, float(i));
    float amp = pow(persistence, float(i));
    total += interpNoise3D(x * freq, y * freq, z * freq) * amp;
  }
  return total;
}

vec3 random3(vec3 p) {
	return fract(sin(vec3(
                    dot(p, vec3(127.1, 311.7, 99.2)),
                    dot(p, vec3(269.5, 183.3, 77.9)),
                    dot(p, vec3(381.8, 98.2, 149.4))))
                 * 1.5);
}

float worley(vec3 p) {
  p *= 60.0;
  vec3 pInt = floor(p);
  vec3 pFract = fract(p);
  float minDist = 1.0;
  
  for (int z = -1; z <= 1; ++z) {
    for (int y = -1; y <= 1; ++y) {
        for (int x = -1; x <= 1; ++x) {
            vec3 neighbor = vec3(float(x), float(y), float(z)); 
            vec3 point = random3(pInt + neighbor);
            vec3 diff = neighbor + point - pFract;
            float dist = length(diff);
            minDist = min(minDist, dist);
        }
    }
  }
  
  return minDist;
}

float surflet(vec3 p, vec3 gridPoint) {
  vec3 t2 = abs(p - gridPoint);
  vec3 t = vec3(1.0) - 6.0 * pow(t2, vec3(5.0)) + 15.0 * pow(t2, vec3(4.0)) - 10.0 * pow(t2, vec3(3.0));
  vec3 gradient = noise3D(gridPoint) * 2.0 - vec3(1.0);
  vec3 diff = p - gridPoint;
  float height = dot(diff, gradient);
  return height * t.x * t.y * t.z;
}

float perlin(vec3 p) {
	float surfletSum = 0.f;
	for(int dx = 0; dx <= 1; ++dx) {
		for(int dy = 0; dy <= 1; ++dy) {
			for(int dz = 0; dz <= 1; ++dz) {
				surfletSum += surflet(p, floor(p) + vec3(dx, dy, dz));
			}
		}
	}
	return surfletSum;
}

float temperature(vec3 p) {
  return float(u_Temp) / 10.0 * perlin(p.xyz);
}

float precipitation(vec3 p) {
  return float(u_Precip) / 10.0 * perlin(p.zyx);
}

int biome(vec3 p) {
  float temp = temperature(p);
  float precip = precipitation(p);
  if (temp <= 0.005) {
    if (precip <= 0.005) {
      return 1;  // temperate
    } else {
      return 2;  // tundra
    }
  } else {
    if (precip <= 0.0001) {
      return 3;  // desert
    } else {
      return 4;  // tropical
    }
  }
}

void main()
{
  fs_Pos = vs_Pos;
  fs_CameraPos = inverse(u_ViewProj) * vec4(0, 0, 0, 1);
  mat3 invTranspose = mat3(u_ModelInvTr);
  fs_Nor = vec4(invTranspose * vec3(vs_Nor), 0);          // Pass the vertex normals to the fragment shader for interpolation.
                                                          // Transform the geometry's normals by the inverse transpose of the
                                                          // model matrix. This is necessary to ensure the normals remain
                                                          // perpendicular to the surface after the surface is transformed by
                                                          // the model matrix.*/

  vec4 modelposition = u_Model * vs_Pos;   // Temporarily store the transformed vertex positions for use below

  lightPos.x += 10.0 * cos(float(u_Time) * 0.005);
  lightPos.y += 10.0 * sin(float(u_Time) * 0.005);
  fs_LightVec = normalize(lightPos - modelposition);  // Compute the direction in which the light source lies

  // displace terrain by biome
  int biome = biome(modelposition.xyz);
  fs_Biome = float(biome);
  if (biome == 2) {
    // add mountains to tundra
    modelposition.xyz += 0.08 * parabola(float(u_Time) * 0.001) * pow(worley(modelposition.xyz), 3.0) * vec3(vs_Nor);
  } else if (biome == 3) {
    // add canyons to desert
    float noise = worley(modelposition.xyz / 4.0);
    if (noise < 0.4) {
      modelposition.xyz -= 0.25 * (0.5 * easeInOutQuart(sin(float(u_Time) * 0.003)) + 1.0) * vec3(vs_Nor);
    }
  }
  modelposition.xyz += 0.64 * fbm3D(modelposition.xyz + vec3(sin(float(u_Time) * .0001))) * vec3(vs_Nor);
  fs_Height = length(modelposition.xyz);
  fs_Col = vs_Col;

  // TODO recalculate surface normals
  /*
  float d = 0.00005;
  fs_Nor = 
    vec4(
      fbm3D(modelposition.xyz + vec3(d, 0, 0)) - fbm3D(modelposition.xyz - vec3(d, 0, 0)), 
      fbm3D(modelposition.xyz + vec3(0, d, 0)) - fbm3D(modelposition.xyz - vec3(0, d, 0)), 
      fbm3D(modelposition.xyz + vec3(0, 0, d)) - fbm3D(modelposition.xyz - vec3(0, 0, d)), 
      0.0
    );*/
      
  gl_Position = u_ViewProj * modelposition;// gl_Position is a built-in variable of OpenGL which is
                                           // used to render the final positions of the geometry's vertices
}
