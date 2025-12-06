# WATCH_DOGS 1 Shader Compiler
This repo includes everything you need to recompile the shader database for WATCH_DOGS 1

## Requirements:
1. [Windows SDK](https://developer.microsoft.com/en-us/windows/downloads/windows-sdk/)
2. [Python](https://www.python.org/downloads/)

## Compliation
- Download the entire repo.
- Run `CompileShaders.py`
- Enter a shader family you wish to compile (e.g. `Mesh_DriverGeneric`, family names can be found in `engine\shaders\meta\filelist.meta.xml.txt`)
- Or if you need to compile all shaders, type in `.fx` should compile everything

## Loading shaders from disk
- You can unpack `Watch_Dogs\data_win64\shadersobj.fat` with gibbed.disrupt, rename both `shadersobj.fat` and `shadersobj.dat` to `shadersobj.fat.bak` and `shadersobj.dat.bak`
- Move `Watch_Dogs\data_win64\shadersobj_unpack\engine` folder to `Watch_Dogs\data_win64\`
- Game will load from disk shader files from now on

