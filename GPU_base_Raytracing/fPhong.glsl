#version 330

#define FLT_MAX 3.402823466e+38

in vec3 N3; 
in vec3 L3; 
in vec3 V3; 
in vec3 wV;
in vec3 wP;
in vec3 wN;

out vec4 fColor;

struct Material {
	vec4  k_d;	// diffuse coefficient
	vec4  k_s;	// specular coefficient
	float n;	// specular exponent
};

struct Sphere {
	vec4     center;
	float    radius;
	Material mtl;
};

struct Ray {
	vec3 pos;
	vec3 dir;
};

struct HitInfo {
	vec4     position; // world position?
	vec3     normal;
	Material mtl;
	float t;
};

uniform mat4 uModelMat; 
uniform mat4 uViewMat; 
uniform mat4 uProjMat; 
uniform vec4 uLPos; 
uniform vec4 uLIntensity;
uniform vec4 uAmb; 
uniform vec4 uDif; 
uniform vec4 uSpc; 
uniform float uShininess; 
uniform samplerCube uCube;
uniform vec4 uEPos;
uniform int uNumSphere;
uniform Sphere uSpheres[20];
uniform int uBounceLimit;
uniform int uDrawingMode;



bool IntersectRay( inout HitInfo hit, Ray ray );

// Shades the given point and returns the computed color.
vec4 Shade(vec3 pos, vec3 normal)
{
	vec3 LPos = uLPos.xyz;
	vec4 color = vec4(1,1,1,1);

	HitInfo h;
	Ray lightRay;
	lightRay.dir = normalize(pos- LPos);
	//light로부터 렌더링하고자 하는 fragment지점으로 ray를 발사
	lightRay.pos = LPos.xyz;

	if(!IntersectRay(h, lightRay)) return color;
	// light로부터 렌더링하고자 하는 fragment에
		
	if(h.t < distance(LPos, pos) - 0.01){
	// light에서 뻗어나온 ray의 길이가 fragment까지의 거리보다 짧으면 그림자를 맺음
	// 0.01은 부동소수점 연산 등에 의한 오차를 보정하기 위한 보정치
		color = vec4(0.4, 0.4, 0.4, 1);
	// 그림자가 생기면 그림자가 생기는 지점의 brightness return	
		}

	else{
		color = vec4(1,1,1,1);} // 그림자가 없으면 1 return

	if(dot(lightRay.dir, normal) > 0){
		color = vec4(1,1,1,1);}

	return color;
}

// Intersects the given ray with all spheres in the scene
// and updates the given ` using the information of the sphere
// that first intersects with the ray.
// Returns true if an intersection is found.
bool IntersectRay( inout HitInfo hit, Ray ray )
{
	bool foundHit = false;

	float minDistRayPosToSph = FLT_MAX;	// ray를 발사하여 가장 가까운 object만 샘플링 해야함
	for ( int i=0; i<uNumSphere; ++i ) { // object들을 루프

		Sphere sph = uSpheres[i];

		vec3 relSphPos = vec3(sph.center.xyz) - ray.pos;
		//ray의 시작점을 원점으로 측정한 구의 postion 좌표

		if(dot(ray.dir, relSphPos)<0) continue; // ray의 방향과 구체의 방향이 반대인 경우는 계산하면 안됨 
		vec3 projectReltoRay = normalize(ray.dir) * dot(ray.dir, relSphPos) /length(ray.dir);
		vec3 rayNormalToSph = relSphPos - projectReltoRay;

		float distRayDirToSph = length(rayNormalToSph);

		if(distRayDirToSph < sph.radius && minDistRayPosToSph > length(projectReltoRay)){
		//ray선과 구의 중심의 거리가 radius보다 작아야 하며, 가장 가까운 object가 샘플링 돼야함

			foundHit = true;
			
			minDistRayPosToSph = length(projectReltoRay);

			float len = sqrt(sph.radius * sph.radius - distRayDirToSph * distRayDirToSph);
			vec3 v = normalize(ray.dir)*len;
			vec3 sphCenterToInterPoint = - rayNormalToSph - v;

			hit.normal = normalize(sphCenterToInterPoint);
			hit.position = vec4(sph.center.xyz + sphCenterToInterPoint, sph.center.w);
			hit.mtl = sph.mtl;
			hit.t = length(relSphPos + sphCenterToInterPoint);
		}
	}

	return foundHit;
}

// Given a ray, returns the shaded color where the ray intersects a sphere.
// If the ray does not hit a sphere, returns the environment color.
vec4 RayTracer( Ray ray )
{
	
	vec4 clr;
	vec4 shade = vec4(1,1,1,1);

	vec3 V = normalize(V3); 

	HitInfo hit;

	Ray r;	// this is the reflection ray
	HitInfo h;	// reflection hit info

	if ( IntersectRay( hit, ray ) ) { // 카메라가 물체를 바라봤을때 부딪힌 곳이 바로 hit
		vec3 view = normalize( -ray.dir );
		//shade = Shade(hit.position.xyz, hit.normal);
		//카메라에서 물체의 fragment를 바라봤을 때 그 그림자를 계산

		r.dir = reflect(ray.dir, hit.normal);
		r.pos = hit.position.xyz;

		shade = Shade(hit.position.xyz, hit.normal);

		
		vec3 L = normalize(L3); 
		vec3 N = normalize(N3); 
		vec3 H = normalize(V+L); 

		float NL = max(dot(N, L), 0); // 노말과 빛 사이의 각도 Normal Light
		float VR = pow(max(dot(H, N), 0), hit.mtl.n);  // 시야와 빛 사이의 각도 View Reflection(Normal)
		clr = uLIntensity*hit.mtl.k_s*VR + uLIntensity*hit.mtl.k_d*NL;

		// Compute reflections
		vec4 k_s = hit.mtl.k_s;
		for ( int bounce=0; bounce<uBounceLimit; bounce++ ) {
		// Bounce Limit만큼 반복

			if ( hit.mtl.k_s.r + hit.mtl.k_s.g + hit.mtl.k_s.b <= 0.0 ) break;
			
			if ( IntersectRay( h, r ) ) {
			
				vec3 L = normalize(L3); 
				vec3 N = normalize(h.normal); 
				vec3 H = normalize(V+L); 

				float NL = max(dot(N, L), 0); 
				float VR = pow(max(dot(H, N), 0), h.mtl.n);

				clr = uLIntensity*h.mtl.k_s*VR + uLIntensity*h.mtl.k_d*NL;
				// 값을 계속 덮어써 최종적으로 도달한 지점만을 샘플링
				shade *= Shade(h.position.xyz, h.normal);
				// 그림자는 특정 지점에 한 번 만 맺혀도 계속 있어야 함으로 누적

				V = -h.normal;

				r.dir = reflect(r.dir, h.normal);
				r.pos = h.position.xyz;

			} else {
				
				
				clr = k_s * texture(uCube, vec3(1,-1,1)*r.dir);
				shade *= Shade(r.pos, r.dir);

				break;	// no more reflections
			}
		}

		
		return  shade * clr;	// 그림자 정보와 ray tracing 정보를 같이 return

	} else {
		return texture(uCube, vec3(1,-1,1)*ray.dir);	// return the environment color
	}
}

void main()
{

	vec3 N = normalize(N3); 
	vec3 L = normalize(L3); 
	vec3 V = normalize(V3); 
	vec3 H = normalize(V+L); 
	
	float NL = max(dot(N, L), 0); // 노말과 빛 사이의 각도 Normal Light
	float VR = pow(max(dot(H, N), 0), uShininess);  // 시야와 빛 사이의 각도 View Reflection(Normal)

	if(uDrawingMode == 0) 
	{

		vec3 viewDir = wP - wV;
		vec3 dir = reflect(viewDir, wN);

		fColor = uAmb + uLIntensity*uDif*NL + uLIntensity*uSpc*VR; 
		fColor.w = 1; 

		fColor += uSpc*texture(uCube, vec3(1,-1,1)*dir);
	}
	else if(uDrawingMode == 1)
	{
		Ray r;
		r.pos = wV; // r의 위치는 카메라의 위치
		r.dir = normalize(wP - wV); // r의 dir은 카메라가 해당 fragment를 바라보는 방향


		fColor = uAmb + uLIntensity*uDif*NL + uLIntensity*uSpc*VR; 
		fColor.w = 1;

		fColor += uSpc * RayTracer(r);
		
	}
}
