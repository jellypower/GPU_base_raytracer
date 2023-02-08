#version 330

in  vec4 color;
in  vec3 pos;
in vec3 wV;
in vec3 wP;

out vec4 fColor;

uniform samplerCube uCube;

void
main()
{
	vec3 viewDir = wP - wV;
	fColor = texture(uCube, vec3(1,-1,1)*viewDir);
}
