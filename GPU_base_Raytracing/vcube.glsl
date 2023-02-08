#version 330

in  vec4 vPosition;
in  vec4 vColor;
out vec3 pos;
out vec4 color;

out vec3 wV;
out vec3 wP;

uniform mat4 uModelMat; 
uniform mat4 uViewMat; 
uniform mat4 uProjMat; 
uniform vec4 uColor;
uniform vec4 uEPos;


void main()
{	gl_Position  = uProjMat*uViewMat*uModelMat*vPosition;
	gl_Position *= vec4(1,1,-1,1);

	color = vColor;
	pos = vPosition.xyz;

	wP = (uModelMat*vPosition).xyz;
	wV = uEPos.xyz;
}
