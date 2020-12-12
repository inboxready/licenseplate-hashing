
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