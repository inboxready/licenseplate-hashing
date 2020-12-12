
package h3d.impl;

#if (hldx && haxe_ver < 4)

class DirectXDriver extends h3d.impl.Driver {

	public function new() {
		throw "HL DirectX support requires Haxe 4.0+";
	}

}

#elseif (hldx && !dx12)

import h3d.impl.Driver;
import dx.Driver;
import h3d.mat.Pass;

private class ShaderContext {
	public var shader : Shader;
	public var globalsSize : Int;
	public var paramsSize : Int;
	public var texturesCount : Int;
	public var textures2DCount : Int;
	public var bufferCount : Int;
	public var paramsContent : hl.Bytes;
	public var globals : dx.Resource;
	public var params : dx.Resource;
	public var samplersMap : Array<Int>;
	#if debug
	public var debugSource : String;
	#end
	public function new(shader) {
		this.shader = shader;
	}
}

private class CompiledShader {
	public var vertex : ShaderContext;
	public var fragment : ShaderContext;
	public var layout : Layout;
	public var inputs : InputNames;
	public var offsets : Array<Int>;
	public function new() {
	}
}

enum PipelineKind {
	Vertex;
	Pixel;
}

class PipelineState {
	public var kind : PipelineKind;
	public var samplers = new hl.NativeArray<SamplerState>(64);
	public var samplerBits = new Array<Int>();
	public var resources = new hl.NativeArray<ShaderResourceView>(64);
	public var buffers = new hl.NativeArray<dx.Resource>(16);
	public function new(kind) {
		this.kind = kind;
		for(i in 0...64 ) samplerBits[i] = -1;
	}
}

class DirectXDriver extends h3d.impl.Driver {

	static inline var NTARGETS = 8;
	static inline var VIEWPORTS_ELTS = 6 * NTARGETS;
	static inline var RECTS_ELTS = 4 * NTARGETS;
	static inline var BLEND_FACTORS = NTARGETS;

	public static var CACHE_FILE : { input : String, output : String } = null;
	var cacheFileData : Map<String,haxe.io.Bytes>;
	#if debug_shader_cache
	var cacheFileDebugData = new Map<String, String>();
	#end

	var driver : DriverInstance;
	var shaders : Map<Int,CompiledShader>;

	var hasDeviceError = false;

	var defaultTarget : RenderTargetView;
	var defaultDepth : DepthBuffer;
	var defaultDepthInst : h3d.mat.DepthBuffer;
	var extraDepthInst : h3d.mat.DepthBuffer;

	var viewport : hl.BytesAccess<hl.F32> = new hl.Bytes(4 * VIEWPORTS_ELTS);
	var rects : hl.BytesAccess<Int> = new hl.Bytes(4 * RECTS_ELTS);
	var box = new dx.Resource.ResourceBox();
	var strides : Array<Int> = [];
	var offsets : Array<Int> = [];
	var currentShader : CompiledShader;
	var currentIndex : IndexBuffer;
	var currentDepth : DepthBuffer;
	var currentTargets = new hl.NativeArray<RenderTargetView>(16);
	var currentTargetResources = new hl.NativeArray<ShaderResourceView>(16);
	var vertexShader : PipelineState;
	var pixelShader : PipelineState;
	var currentVBuffers = new hl.NativeArray<dx.Resource>(16);
	var frame : Int;
	var currentMaterialBits = -1;
	var currentStencilMaskBits = -1;
	var currentStencilOpBits = -1;
	var currentStencilRef = 0;
	var currentColorMask = -1;
	var currentColorMaskIndex = -1;
	var colorMaskIndexes : Map<Int, Int>;
	var colorMaskIndex = 1;
	var targetsCount = 1;
	var allowDraw = false;
	var maxSamplers = 16;

	var depthStates : Map<Int,{ def : DepthStencilState, stencils : Array<{ op : Int, mask : Int, state : DepthStencilState }> }>;
	var blendStates : Map<Int,BlendState>;
	var rasterStates : Map<Int,RasterState>;
	var samplerStates : Map<Int,SamplerState>;
	var currentDepthState : DepthStencilState;
	var currentBlendState : BlendState;
	var currentRasterState : RasterState;
	var blendFactors : hl.BytesAccess<hl.F32> = new hl.Bytes(4 * BLEND_FACTORS);

	var outputWidth : Int;
	var outputHeight : Int;
	var hasScissor = false;
	var shaderVersion : String;

	var window : dx.Window;
	var curTexture : h3d.mat.Texture;

	var mapCount : Int;
	var updateResCount : Int;
	var onContextLost : Void -> Void;

	public var backBufferFormat : dx.Format = R8G8B8A8_UNORM;
	public var depthStencilFormat : dx.Format = D24_UNORM_S8_UINT;

	public function new() {
		window = @:privateAccess dx.Window.windows[0];
		Driver.setErrorHandler(onDXError);
		reset();
	}

	public dynamic function getDriverFlags() : dx.Driver.DriverInitFlags {
		var options : dx.Driver.DriverInitFlags = None;
		#if debug
		options |= DebugLayer;
		#end
		return options;
	}

	function reset() {
		allowDraw = false;
		targetsCount = 1;
		currentMaterialBits = -1;
		currentStencilMaskBits = -1;
		currentStencilOpBits = -1;
		if( shaders != null ) {
			for( s in shaders ) {
				s.fragment.shader.release();
				s.vertex.shader.release();
				s.layout.release();
			}
		}
		if( depthStates != null ) for( s in depthStates ) { if( s.def != null ) s.def.release(); for( s in s.stencils ) if( s.state != null ) s.state.release(); }
		if( blendStates != null ) for( s in blendStates ) if( s != null ) s.release();
		if( rasterStates != null ) for( s in rasterStates ) if( s != null ) s.release();
		if( samplerStates != null ) for( s in samplerStates ) if( s != null ) s.release();
		shaders = new Map();
		depthStates = new Map();
		blendStates = new Map();
		rasterStates = new Map();
		samplerStates = new Map();
		vertexShader = new PipelineState(Vertex);
		pixelShader = new PipelineState(Pixel);
		colorMaskIndexes = new Map();

		try
			driver = Driver.create(window, backBufferFormat, getDriverFlags())
		catch( e : Dynamic )
			throw "Failed to initialize DirectX driver (" + e + ")";

		if( driver == null ) throw "Failed to initialize DirectX driver";

		var version = Driver.getSupportedVersion();
		shaderVersion = if( version < 10 ) "3_0" else if( version < 11 ) "4_0" else "5_0";

		Driver.iaSetPrimitiveTopology(TriangleList);
		defaultDepthInst = new h3d.mat.DepthBuffer(-1, -1);
		for( i in 0...VIEWPORTS_ELTS )
			viewport[i] = 0;
		for( i in 0...RECTS_ELTS )
			rects[i] = 0;
		for( i in 0...BLEND_FACTORS )
			blendFactors[i] = 0;
	}

	override function dispose() {
		Driver.disposeDriver(driver);
		driver = null;
	}

	function onDXError(code:Int,reason:Int,line:Int) {
		if( code != 0x887A0005 /*DXGI_ERROR_DEVICE_REMOVED*/ )
			throw "DXError "+StringTools.hex(code)+" line "+line;
		//if( !hasDeviceError ) trace("DX_REMOVED "+StringTools.hex(reason)+":"+line);
		hasDeviceError = true;
	}

	override function resize(width:Int, height:Int)  {
		if( defaultDepth != null ) {
			defaultDepth.view.release();
			defaultDepth.res.release();
		}
		if( defaultTarget != null ) {
			defaultTarget.release();
			defaultTarget = null;
		}

		if( !Driver.resize(width, height, backBufferFormat) )
			throw "Failed to resize backbuffer to " + width + "x" + height;

		var depthDesc = new Texture2dDesc();
		depthDesc.width = width;
		depthDesc.height = height;
		depthDesc.format = depthStencilFormat;
		depthDesc.bind = DepthStencil;
		var depth = Driver.createTexture2d(depthDesc);
		if( depth == null ) throw "Failed to create depthBuffer";
		var depthView = Driver.createDepthStencilView(depth,depthStencilFormat);
		defaultDepth = { res : depth, view : depthView };
		@:privateAccess {
			defaultDepthInst.b = defaultDepth;
			defaultDepthInst.width = width;
			defaultDepthInst.height = height;
		}

		var buf = Driver.getBackBuffer();
		defaultTarget = Driver.createRenderTargetView(buf);
		Driver.clearColor(defaultTarget, 0, 0, 0, 0);
		buf.release();

		outputWidth = width;
		outputHeight = height;

		setRenderTarget(null);

		if( extraDepthInst != null ) @:privateAccess {
			extraDepthInst.width = width;
			extraDepthInst.height = height;
			if( extraDepthInst.b != null ) disposeDepthBuffer(extraDepthInst);
			extraDepthInst.b = allocDepthBuffer(extraDepthInst);
		}
	}

	override function begin(frame:Int) {
		mapCount = 0;
		updateResCount = 0;
		this.frame = frame;
		setRenderTarget(null);
	}

	override function isDisposed() {
		return hasDeviceError;
	}

	override function init( onCreate : Bool -> Void, forceSoftware = false ) {
		onContextLost = onCreate.bind(true);
		haxe.Timer.delay(onCreate.bind(false), 1);
	}

	override function clear(?color:h3d.Vector, ?depth:Float, ?stencil:Int) {
		if( color != null ) {
			for( i in 0...targetsCount )
				Driver.clearColor(currentTargets[i], color.r, color.g, color.b, color.a);
		}
		if( currentDepth != null && (depth != null || stencil != null) )
			Driver.clearDepthStencilView(currentDepth.view, depth, stencil);
	}

	override function getDriverName(details:Bool) {
		var desc = "DirectX" + Driver.getSupportedVersion();
		if( details ) desc += " " + Driver.getDeviceName();
		return desc;
	}

	public function forceDeviceError() {
		hasDeviceError = true;
	}

	override function present() {
		if( defaultTarget == null ) return;
		var old = hxd.System.allowTimeout;
		if( old ) hxd.System.allowTimeout = false;
		Driver.present(window.vsync ? 1 : 0, None);
		if( old ) hxd.System.allowTimeout = true;

		if( hasDeviceError ) {
			Sys.println("----------- OnContextLost ----------");
			hasDeviceError = false;
			dispose();
			reset();
			onContextLost();
		}

	}

	override function getDefaultDepthBuffer():h3d.mat.DepthBuffer {
		if( extraDepthInst == null ) @:privateAccess {
			extraDepthInst = new h3d.mat.DepthBuffer(0, 0);
			extraDepthInst.width = outputWidth;
			extraDepthInst.height = outputHeight;
			extraDepthInst.b = allocDepthBuffer(extraDepthInst);
		}
		return extraDepthInst;
	}

	override function allocVertexes(m:ManagedBuffer):VertexBuffer {
		var size = m.size * m.stride * 4;
		var uniform = m.flags.has(UniformBuffer);
		var res = uniform ? dx.Driver.createBuffer(size, Dynamic, ConstantBuffer, CpuWrite, None, 0, null) : dx.Driver.createBuffer(size, Default, VertexBuffer, None, None, 0, null);
		if( res == null ) return null;
		return { res : res, count : m.size, stride : m.stride, uniform : uniform };
	}

	override function allocIndexes( count : Int, is32 : Bool ) : IndexBuffer {
		var bits = is32 ? 2 : 1;
		var res = dx.Driver.createBuffer(count << bits, Default, IndexBuffer, None, None, 0, null);
		if( res == null ) return null;
		return { res : res, count : count, bits : bits  };
	}

	override function allocDepthBuffer( b : h3d.mat.DepthBuffer ) : DepthBuffer {
		var depthDesc = new Texture2dDesc();
		depthDesc.width = b.width;
		depthDesc.height = b.height;
		depthDesc.format = D24_UNORM_S8_UINT;
		depthDesc.bind = DepthStencil;
		var depth = Driver.createTexture2d(depthDesc);
		if( depth == null )
			return null;
		return { res : depth, view : Driver.createDepthStencilView(depth,depthDesc.format) };
	}

	override function disposeDepthBuffer(b:h3d.mat.DepthBuffer) @:privateAccess {
		var d = b.b;
		b.b = null;
		d.view.release();
		d.res.release();
	}

	override function captureRenderBuffer( pixels : hxd.Pixels ) {
		var rt = curTexture;
		if( rt == null )
			throw "Can't capture main render buffer in DirectX";
		captureTexPixels(pixels, rt, 0, 0);
	}

	override function isSupportedFormat( fmt : hxd.PixelFormat ) {
		return switch( fmt ) {
		case RGB8, RGB16F, ARGB, BGRA, SRGB: false;
		default: true;
		}
	}

	function getTextureFormat( t : h3d.mat.Texture ) : dx.Format {
		return switch( t.format ) {
		case RGBA: R8G8B8A8_UNORM;
		case RGBA16F: R16G16B16A16_FLOAT;
		case RGBA32F: R32G32B32A32_FLOAT;
		case R32F: R32_FLOAT;
		case R16F: R16_FLOAT;
		case R8: R8_UNORM;
		case RG8: R8G8_UNORM;
		case RG16F: R16G16_FLOAT;
		case RG32F: R32G32_FLOAT;
		case RGB32F: R32G32B32_FLOAT;
		case RGB10A2: R10G10B10A2_UNORM;
		case RG11B10UF: R11G11B10_FLOAT;
		case SRGB_ALPHA: R8G8B8A8_UNORM_SRGB;
		case S3TC(n):
			switch( n ) {
			case 1: BC1_UNORM;
			case 2: BC2_UNORM;
			case 3: BC3_UNORM;
			case 4: BC4_UNORM;
			case 5: BC5_UNORM;
			case 6: BC6H_UF16;
			case 7: BC7_UNORM;
			default: throw "assert";
			}
		default: throw "Unsupported texture format " + t.format;
		}
	}

	override function allocTexture(t:h3d.mat.Texture):Texture {

		var mips = 1;
		if( t.flags.has(MipMapped) )
			mips = t.mipLevels;

		var rt = t.flags.has(Target);
		var isCube = t.flags.has(Cube);
		var isArray = t.flags.has(IsArray);

		var desc = new Texture2dDesc();
		desc.width = t.width;
		desc.height = t.height;
		desc.format = getTextureFormat(t);

		if( t.format.match(S3TC(_)) && (t.width & 3 != 0 || t.height & 3 != 0) )
			throw t+" is compressed "+t.width+"x"+t.height+" but should be a 4x4 multiple";

		desc.usage = Default;
		desc.bind = ShaderResource;
		desc.mipLevels = mips;
		if( rt )
			desc.bind |= RenderTarget;
		if( isCube ) {
			desc.arraySize = 6;
			desc.misc |= TextureCube;
		}
		if( isArray )
			desc.arraySize = t.layerCount;
		if( t.flags.has(MipMapped) && !t.flags.has(ManualMipMapGen) ) {
			if( t.format.match(S3TC(_)) )
				throw "Cannot generate mipmaps for compressed texture "+t;
			desc.bind |= RenderTarget;
			desc.misc |= GenerateMips;
		}
		var tex = Driver.createTexture2d(desc);
		if( tex == null )
			return null;

		t.lastFrame = frame;
		t.flags.unset(WasCleared);

		var vdesc = new ShaderResourceViewDesc();
		vdesc.format = desc.format;
		vdesc.dimension = isCube ? TextureCube : isArray ? Texture2DArray : Texture2D;
		vdesc.arraySize = desc.arraySize;
		vdesc.start = 0; // top mip level
		vdesc.count = -1; // all mip levels
		var view = Driver.createShaderResourceView(tex, vdesc);
		return { res : tex, view : view, rt : rt ? [] : null, mips : mips };
	}

	override function disposeTexture( t : h3d.mat.Texture ) {
		var tt = t.t;
		if( tt == null ) return;
		t.t = null;
		if( tt.view != null ) tt.view.release();
		if( tt.res != null ) tt.res.release();
		if( tt.rt != null )
			for( rt in tt.rt )
				if( rt != null )
					rt.release();
	}

	override function disposeVertexes(v:VertexBuffer) {
		v.res.release();
	}

	override function disposeIndexes(i:IndexBuffer) {
		i.res.release();
	}

	override function generateMipMaps(texture:h3d.mat.Texture) {
		if( hasDeviceError ) return;
		Driver.generateMips(texture.t.view);
	}

	function updateBuffer( res : dx.Resource, bytes : hl.Bytes, startByte : Int, bytesCount : Int ) {
		box.left = startByte;
		box.top = 0;
		box.front = 0;
		box.right = startByte + bytesCount;
		box.bottom = 1;
		box.back = 1;
		res.updateSubresource(0, box, bytes, 0, 0);
		updateResCount++;
	}

	override function uploadIndexBuffer(i:IndexBuffer, startIndice:Int, indiceCount:Int, buf:hxd.IndexBuffer, bufPos:Int) {
		if( hasDeviceError ) return;
		updateBuffer(i.res, hl.Bytes.getArray(buf.getNative()).offset(bufPos << i.bits), startIndice << i.bits, indiceCount << i.bits);
	}

	override function uploadIndexBytes(i:IndexBuffer, startIndice:Int, indiceCount:Int, buf:haxe.io.Bytes, bufPos:Int) {
		if( hasDeviceError ) return;
		updateBuffer(i.res, @:privateAccess buf.b.offset(bufPos << i.bits), startIndice << i.bits, indiceCount << i.bits);
	}

	override function uploadVertexBuffer(v:VertexBuffer, startVertex:Int, vertexCount:Int, buf:hxd.FloatBuffer, bufPos:Int) {
		if( hasDeviceError ) return;
		var data = hl.Bytes.getArray(buf.getNative()).offset(bufPos<<2);
		if( v.uniform ) {
			if( startVertex != 0 ) throw "assert";
			var ptr = v.res.map(0, WriteDiscard, true, null);
			if( ptr == null ) throw "Can't map buffer";
			ptr.blit(0, data, 0, vertexCount * v.stride << 2);
			v.res.unmap(0);
			return;
		}
		updateBuffer(v.res, data, startVertex * v.stride << 2, vertexCount * v.stride << 2);
	}

	override function uploadVertexBytes(v:VertexBuffer, startVertex:Int, vertexCount:Int, buf:haxe.io.Bytes, bufPos:Int) {
		if( hasDeviceError ) return;
		if( v.uniform ) {
			if( startVertex != 0 ) throw "assert";
			var ptr = v.res.map(0, WriteDiscard, true, null);
			if( ptr == null ) throw "Can't map buffer";
			ptr.blit(0, buf, 0, vertexCount * v.stride << 2);
			v.res.unmap(0);
			return;
		}
		updateBuffer(v.res, @:privateAccess buf.b.offset(bufPos << 2), startVertex * v.stride << 2, vertexCount * v.stride << 2);
	}

	override function readIndexBytes(v:IndexBuffer, startIndice:Int, indiceCount:Int, buf:haxe.io.Bytes, bufPos:Int) {
		var tmp = dx.Driver.createBuffer(indiceCount << v.bits, Staging, None, CpuRead | CpuWrite, None, 0, null);
		box.left = startIndice << v.bits;
		box.top = 0;
		box.front = 0;
		box.right = (startIndice + indiceCount) << v.bits;
		box.bottom = 1;
		box.back = 1;
		tmp.copySubresourceRegion(0, 0, 0, 0, v.res, 0, box);
		var ptr = tmp.map(0, Read, true, null);
		@:privateAccess buf.b.blit(bufPos, ptr, 0, indiceCount << v.bits);
		tmp.unmap(0);
		tmp.release();
	}

	override function readVertexBytes(v:VertexBuffer, startVertex:Int, vertexCount:Int, buf:haxe.io.Bytes, bufPos:Int) {
		var tmp = dx.Driver.createBuffer(vertexCount * v.stride * 4, Staging, None, CpuRead | CpuWrite, None, 0, null);
		box.left = startVertex * v.stride * 4;
		box.top = 0;
		box.front = 0;
		box.right = (startVertex + vertexCount) * 4 * v.stride;
		box.bottom = 1;
		box.back = 1;
		tmp.copySubresourceRegion(0, 0, 0, 0, v.res, 0, box);
		var ptr = tmp.map(0, Read, true, null);
		@:privateAccess buf.b.blit(bufPos, ptr, 0, vertexCount * v.stride * 4);
		tmp.unmap(0);
		tmp.release();
	}

	override function capturePixels(tex:h3d.mat.Texture, layer:Int, mipLevel:Int, ?region:h2d.col.IBounds) : hxd.Pixels {
		var pixels : hxd.Pixels;
		if (region != null) {
			if (region.xMax > tex.width) region.xMax = tex.width;
			if (region.yMax > tex.height) region.yMax = tex.height;
			if (region.xMin < 0) region.xMin = 0;
			if (region.yMin < 0) region.yMin = 0;
			var w = region.width >> mipLevel;
			var h = region.height >> mipLevel;
			if( w == 0 ) w = 1;
			if( h == 0 ) h = 1;
			pixels = hxd.Pixels.alloc(w, h, tex.format);
			captureTexPixels(pixels, tex, layer, mipLevel, region.xMin, region.yMin);
		} else {
			var w = tex.width >> mipLevel;
			var h = tex.height >> mipLevel;
			if( w == 0 ) w = 1;
			if( h == 0 ) h = 1;
			pixels = hxd.Pixels.alloc(w, h, tex.format);
			captureTexPixels(pixels, tex, layer, mipLevel);
		}
		return pixels;
	}

	function captureTexPixels( pixels: hxd.Pixels, tex:h3d.mat.Texture, layer:Int, mipLevel:Int, x : Int = 0, y : Int = 0)  {

		if( pixels.width == 0 || pixels.height == 0 )
			return pixels;

		var desc = new Texture2dDesc();