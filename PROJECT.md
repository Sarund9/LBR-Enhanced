

# Project Specification

Shader files are separated into categories based on what they do

## Shader categories

### World Shaders
All shaders contained in `world*` folders.
- Shader Engine entry points
- Must declare the `#version`
- Never contains actual source code
- Actual shaders are Program/Gbuffer Shaders
- 

### Gbuffer Shaders
All shaders contained in `gbuffer`
Actual shader program, included by World Shaders.
Contains implementation of Geometry Passes.

Uses `__VERTEX__` and `__PIXEL__` to declare vertex/pixel shaders.


### Program Shaders
All shaders contained in `program`
Actual shader program, included by World Shaders.
Contains implementation of Screen Passes, and the shadow pass.


### Shader Library
All shaders contained in `lib`



