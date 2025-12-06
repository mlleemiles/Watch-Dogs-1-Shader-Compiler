# WATCH_DOGS 1 Shader Compiler
This repo includes everything you need to recompile the shader database for WATCH_DOGS 1

## Requirements:
1. [Windows SDK](https://developer.microsoft.com/en-us/windows/downloads/windows-sdk/)
2. [Python](https://www.python.org/downloads/)

## Compilation
WARNING: You must recompile all shaders once before compiling a specific shader family
- Download the entire repo
- Add Windows SDK x64 path to you `PATH` environment variable (e.g. `F:\Windows Kits\10\bin\10.0.26100.0\x64\`)
- Run `CompileShaders.py`
- Enter a shader family you wish to compile (e.g. `Mesh_DriverGeneric`, family names can be found in `engine\shaders\meta\filelist.meta.xml.txt`)
- Or if you need to compile all shaders, type in `.fx` should compile everything

## Loading shaders from disk
- You can unpack `Watch_Dogs\data_win64\shadersobj.fat` with gibbed.disrupt, rename both `shadersobj.fat` and `shadersobj.dat` to `shadersobj.fat.bak` and `shadersobj.dat.bak`
- Move `Watch_Dogs\data_win64\shadersobj_unpack\engine` folder to `Watch_Dogs\data_win64\`
- Game will load from disk shader files from now on

