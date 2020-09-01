## 1.10.0 (February 19, 2023)

Graphics:

* added HashLink DirectX12 Driver (requires HL 1.13+)
* support for multimaterial and sub primitive mesh batches
* more support for DDS files (layers, etc.)
* added cascade shadows
* (hl) added threaded async texture loader
* many PBR improvements by @clementlandrin

Other:

* added HBSON
* added shaders matrix array access
* added clipboard support and TextInput copy/paste
* optimize PAK data management
* added HLVideo support
* ... and many many other improvements

## 1.9.1 (March 5, 2021)

HL:
* Another Haxe 4.2.1 fix

## 1.9.0 (February 28, 2021)

HL:
* Fixes compatibility with Haxe 4.2 (requires 4.2.1)

2D:
* More DomKit APIs
* Flow overflow: Hidden and Scroll support
* Text.letterSpacing is now 0 by default
* New Camera implementation (@Yanrishatum)
* Allow different textures for Graphics/TileGroup/SpriteBatch using BatchDrawState (@Yanrishatum)
* <a> link support in HtmlText (@Azrou)

3D:
* Refactor PBR Renderer (begin/end), allow shader injection in RendererFX
* Support for Y-up exported FBX (auto convert to Z-up)
* Support for centimer exported FBX (auto convert to meters)
* Added Texture.lodBias support for mipmaps
* More detailed skin collider support based on joint bounding boxes
* Added HMD large index (models with >64K vertexes)
* PBR Forward support (@ShiroSm