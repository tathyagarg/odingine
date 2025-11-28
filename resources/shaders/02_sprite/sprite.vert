#version 330 core

layout (location = 0) in vec4 vertex;

out vec2 TexCoords;
out vec2 FragPos;

uniform mat4 model;
uniform mat4 projection;
uniform mat4 view;

void main()
{
    gl_Position = projection * view * model * vec4(vertex.xy, 0.0, 1.0);
    TexCoords = vertex.zw;
    FragPos = gl_Position.xy;
}
