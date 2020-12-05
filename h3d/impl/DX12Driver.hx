
package h3d.impl;

#if (hldx && dx12)

import h3d.impl.Driver;
import dx.Dx12;
import haxe.Int64;
import h3d.mat.Pass;
import h3d.mat.Stencil;

private typedef Driver = Dx12;

class TempBuffer {
	public var next : TempBuffer;
	public var buffer : GpuResource;
	public var size : Int;
	public var lastUse : Int;
	public function new() {
	}
	public inline function count() {
		var b = this;
		var k = 0;
		while( b != null ) {
			k++;
			b = b.next;
		}
		return k;
	}
}

class ManagedHeapArray {

	var heaps : Array<ManagedHeap>;
	var type : DescriptorHeapType;
	var size : Int;
	var cursor : Int;

	public function new(type,size) {
		this.type = type;
		this.size = size;
		heaps = [];
	}

	public function reset() {
		cursor = 0;
	}

	public function next() {
		var h = heaps[cursor++];
		if( h == null ) {
			h = new ManagedHeap(type, size);
			heaps.push(h);
		} else
			h.clear();
		return h;
	}

}

class DxFrame {
	public var backBuffer : ResourceData;
	public var depthBuffer : GpuResource;
	public var allocator : CommandAllocator;
	public var commandList : CommandList;
	public var fenceValue : Int64;
	public var toRelease : Array<Resource> = [];
	public var shaderResourceViews : ManagedHeap;
	public var samplerViews : ManagedHeap;
	public var shaderResourceCache : ManagedHeapArray;
	public var samplerCache : ManagedHeapArray;
	public var availableBuffers : TempBuffer;
	public var usedBuffers : TempBuffer;
	public var queryHeaps : Array<QueryHeap> = [];
	public var queriesPending : Array<Query> = [];
	public var queryCurrentHeap : Int;
	public var queryHeapOffset : Int;
	public var queryBuffer : GpuResource;
	public function new() {
	}
}

class CachedPipeline {
	public var bytes : hl.Bytes;
	public var size : Int;
	public var pipeline : GraphicsPipelineState;
	public function new() {
	}
}

class ShaderRegisters {
	public var globals : Int;
	public var params : Int;
	public var buffers : Int;
	public var textures : Int;
	public var samplers : Int;
	public var texturesCount : Int;
	public var textures2DCount : Int;
	public function new() {
	}
}

class CompiledShader {
	public var vertexRegisters : ShaderRegisters;
	public var fragmentRegisters : ShaderRegisters;
	public var inputCount : Int;
	public var inputNames : InputNames;
	public var pipeline : GraphicsPipelineStateDesc;
	public var pipelines : Map<Int,hl.NativeArray<CachedPipeline>> = new Map();
	public var rootSignature : RootSignature;
	public var inputLayout : hl.CArray<InputElementDesc>;
	public var inputOffsets : Array<Int>;
	public var shader : hxsl.RuntimeShader;
	public function new() {
	}
}

@:struct class TempObjects {

	public var renderTargets : hl.BytesAccess<Address>;
	public var depthStencils : hl.BytesAccess<Address>;
	public var vertexViews : hl.CArray<VertexBufferView>;
	public var descriptors2 : hl.NativeArray<DescriptorHeap>;
	@:packed public var heap(default,null) : HeapProperties;
	@:packed public var barrier(default,null) : ResourceBarrier;
	@:packed public var clearColor(default,null) : ClearColor;
	@:packed public var clearValue(default,null) : ClearValue;
	@:packed public var viewport(default,null) : Viewport;
	@:packed public var rect(default,null) : Rect;
	@:packed public var tex2DSRV(default,null) : Tex2DSRV;
	@:packed public var texCubeSRV(default,null) : TexCubeSRV;
	@:packed public var tex2DArraySRV(default,null) : Tex2DArraySRV;
	@:packed public var bufferSRV(default,null) : BufferSRV;
	@:packed public var samplerDesc(default,null) : SamplerDesc;
	@:packed public var cbvDesc(default,null) : ConstantBufferViewDesc;
	@:packed public var rtvDesc(default,null) : RenderTargetViewDesc;

	public var pass : h3d.mat.Pass;

	public function new() {
		renderTargets = new hl.Bytes(8 * 8);
		depthStencils = new hl.Bytes(8);
		vertexViews = hl.CArray.alloc(VertexBufferView, 16);
		pass = new h3d.mat.Pass("default");
		pass.stencil = new h3d.mat.Stencil();
		tex2DSRV.dimension = TEXTURE2D;
		texCubeSRV.dimension = TEXTURECUBE;
		tex2DArraySRV.dimension = TEXTURE2DARRAY;
		tex2DSRV.mipLevels = texCubeSRV.mipLevels = tex2DArraySRV.mipLevels = -1;
		tex2DSRV.shader4ComponentMapping = ShaderComponentMapping.DEFAULT;
		texCubeSRV.shader4ComponentMapping = ShaderComponentMapping.DEFAULT;
		tex2DArraySRV.shader4ComponentMapping = ShaderComponentMapping.DEFAULT;
		bufferSRV.dimension = BUFFER;
		bufferSRV.flags = RAW;
		bufferSRV.shader4ComponentMapping = ShaderComponentMapping.DEFAULT;
		samplerDesc.comparisonFunc = NEVER;
		samplerDesc.maxLod = 1e30;
		descriptors2 = new hl.NativeArray(2);
		barrier.subResource = -1; // all
	}

}

class ManagedHeap {

	public var stride(default,null) : Int;
	var size : Int;
	var start : Int;
	var cursor : Int;
	var limit : Int;
	var type : DescriptorHeapType;
	var heap : DescriptorHeap;
	var address : Address;
	var cpuToGpu : Int64;

	public var available(get,never) : Int;

	public function new(type,size=8) {
		this.type = type;
		this.stride = Driver.getDescriptorHandleIncrementSize(type);
		allocHeap(size);
	}

	function allocHeap( size : Int ) {
		var desc = new DescriptorHeapDesc();
		desc.type = type;
		desc.numDescriptors = size;
		if( type == CBV_SRV_UAV || type == SAMPLER )
			desc.flags = SHADER_VISIBLE;
		heap = new DescriptorHeap(desc);
		limit = cursor = start = 0;
		this.size = size;
		address = heap.getHandle(false);
		cpuToGpu = heap.getHandle(true).value - address.value;
	}

	public dynamic function onFree( prev : DescriptorHeap ) {
		throw "Too many buffers";
	}

	public function alloc( count : Int ) {
		if( cursor >= limit && cursor + count > size ) {
			cursor = 0;
			if( limit == 0 ) {
				var prev = heap;
				allocHeap((size * 3) >> 1);
				onFree(prev);
			}
		}
		if( cursor < limit && cursor + count >= limit ) {
			var prev = heap;
			allocHeap((size * 3) >> 1);
			onFree(prev);
		}
		var pos = cursor;
		cursor += count;
		return address.offset(pos * stride);
	}

	inline function get_available() {
		var d = limit - cursor;
		return d <= 0 ? size + d : d;
	}

	public inline function grow( onFree ) {
		var prev = heap;
		allocHeap((size*3)>>1);
		onFree(prev);
		return heap;
	}

	public function clear() {
		limit = cursor = start = 0;
	}

	public function next() {
		limit = start;
		start = cursor;
	}

	public inline function toGPU( address : Address ) : Address {
		return new Address(address.value + cpuToGpu);
	}

}

class ResourceData {
	public var res : GpuResource;
	public var state : ResourceState;
	public function new() {
	}
}

class BufferData extends ResourceData {
	public var uploaded : Bool;
}

class IndexBufferData extends BufferData {
	public var view : IndexBufferView;
	public var count : Int;
	public var bits : Int;
}

class VertexBufferData extends BufferData {
	public var view : dx.Dx12.VertexBufferView;
	public var stride : Int;
	public var size : Int;
}

class TextureData extends ResourceData {
	public var format : DxgiFormat;
	public var color : h3d.Vector;
	var clearColorChanges : Int;
	public function setClearColor( c : h3d.Vector ) {
		var color = color;
		if( clearColorChanges > 10 || (color.r == c.r && color.g == c.g && color.b == c.b && color.a == c.a) )
			return false;
		clearColorChanges++;
		color.load(c);
		return true;
	}
}

class DepthBufferData extends ResourceData {
}

class QueryData {
	public var heap : Int;
	public var offset : Int;
	public var result : Float;
	public function new() {
	}
}

class DX12Driver extends h3d.impl.Driver {

	static inline var PSIGN_MATID = 0;
	static inline var PSIGN_COLOR_MASK = PSIGN_MATID + 4;
	static inline var PSIGN_UNUSED = PSIGN_COLOR_MASK + 1;
	static inline var PSIGN_STENCIL_MASK = PSIGN_UNUSED + 1;
	static inline var PSIGN_STENCIL_OPS = PSIGN_STENCIL_MASK + 2;
	static inline var PSIGN_RENDER_TARGETS = PSIGN_STENCIL_OPS + 4;
	static inline var PSIGN_BUF_OFFSETS = PSIGN_RENDER_TARGETS + 8;

	var pipelineSignature = new hl.Bytes(64);
	var adlerOut = new hl.Bytes(4);

	var driver : DriverInstance;
	var hasDeviceError = false;
	var window : dx.Window;
	var onContextLost : Void -> Void;
	var frames : Array<DxFrame>;
	var frame : DxFrame;
	var fence : Fence;
	var fenceEvent : WaitEvent;

	var renderTargetViews : ManagedHeap;
	var depthStenciViews : ManagedHeap;
	var indirectCommand : CommandSignature;

	var currentFrame : Int;
	var fenceValue : Int64 = 0;
	var needPipelineFlush = false;
	var currentPass : h3d.mat.Pass;

	var currentWidth : Int;
	var currentHeight : Int;

	var currentShader : CompiledShader;
	var compiledShaders : Map<Int,CompiledShader> = new Map();
	var compiler : ShaderCompiler;
	var currentIndex : IndexBuffer;

	var tmp : TempObjects;
	var currentRenderTargets : Array<h3d.mat.Texture> = [];
	var defaultDepth : h3d.mat.DepthBuffer;
	var depthEnabled = true;
	var curStencilRef : Int = -1;
	var rtWidth : Int;
	var rtHeight : Int;
	var frameCount : Int;
	var tsFreq : haxe.Int64;

	public static var INITIAL_RT_COUNT = 1024;
	public static var BUFFER_COUNT = 2;
	public static var DEVICE_NAME = null;
	public static var DEBUG = false;

	public function new() {
		window = @:privateAccess dx.Window.windows[0];
		reset();
	}

	override function hasFeature(f:Feature) {
		return switch(f) {
		case Queries, BottomLeftCoords:
			false;
		default:
			true;
		};
	}

	override function isSupportedFormat(fmt:h3d.mat.Data.TextureFormat):Bool {
		return true;
	}

	function reset() {
		var flags = new DriverInitFlags();
		if( DEBUG ) flags.set(DriverInitFlag.DEBUG);
		driver = Driver.create(window, flags, DEVICE_NAME);
		frames = [];
		for(i in 0...BUFFER_COUNT) {
			var f = new DxFrame();
			f.backBuffer = new ResourceData();
			f.allocator = new CommandAllocator(DIRECT);
			f.commandList = new CommandList(DIRECT, f.allocator, null);
			f.commandList.close();
			f.shaderResourceCache = new ManagedHeapArray(CBV_SRV_UAV, 1024);
			f.samplerCache = new ManagedHeapArray(SAMPLER, 1024);
			frames.push(f);
		}
		fence = new Fence(0, NONE);
		fenceEvent = new WaitEvent(false);
		tmp = new TempObjects();

		renderTargetViews = new ManagedHeap(RTV, INITIAL_RT_COUNT);
		depthStenciViews = new ManagedHeap(DSV, INITIAL_RT_COUNT);
		renderTargetViews.onFree = function(prev) frame.toRelease.push(prev);
		depthStenciViews.onFree = function(prev) frame.toRelease.push(prev);
		defaultDepth = new h3d.mat.DepthBuffer(0,0, Depth24Stencil8);

		var desc = new CommandSignatureDesc();
		desc.byteStride = 5 * 4;
		desc.numArgumentDescs = 1;
		desc.argumentDescs = new IndirectArgumentDesc();
		desc.argumentDescs.type = DRAW_INDEXED;
		indirectCommand = Driver.createCommandSignature(desc,null);

		tsFreq = Driver.getTimestampFrequency();

		compiler = new ShaderCompiler();
		resize(window.width, window.height);
	}

	function beginFrame() {
		frameCount = hxd.Timer.frameCount;
		currentFrame = Driver.getCurrentBackBufferIndex();
		frame = frames[currentFrame];
		frame.allocator.reset();
		frame.commandList.reset(frame.allocator, null);
		while( frame.toRelease.length > 0 )
			frame.toRelease.pop().release();
		beginQueries();

		var used = frame.usedBuffers;
		var b = frame.availableBuffers;
		var prev = null;
		while( b != null ) {
			if( b.lastUse < frameCount - 120 ) {
				b.buffer.release();
				b = b.next;
			} else {
				var n = b.next;
				b.next = used;
				used = b;
				b = n;
			}
		}
		frame.availableBuffers = used;
		frame.usedBuffers = null;

		transition(frame.backBuffer, RENDER_TARGET);
		frame.commandList.iaSetPrimitiveTopology(TRIANGLELIST);

		renderTargetViews.next();
		depthStenciViews.next();
		curStencilRef = -1;
		currentIndex = null;

		setRenderTarget(null);


		frame.shaderResourceCache.reset();
		frame.samplerCache.reset();
		frame.shaderResourceViews = frame.shaderResourceCache.next();
		frame.samplerViews = frame.samplerCache.next();

		var arr = tmp.descriptors2;
		arr[0] = @:privateAccess frame.shaderResourceViews.heap;
		arr[1] = @:privateAccess frame.samplerViews.heap;
		frame.commandList.setDescriptorHeaps(arr);
	}

	override function clear(?color:Vector, ?depth:Float, ?stencil:Int) {
		if( color != null ) {
			var clear = tmp.clearColor;
			clear.r = color.r;
			clear.g = color.g;
			clear.b = color.b;
			clear.a = color.a;
			var count = currentRenderTargets.length;
			if( count == 0 ) count = 1;
			for( i in 0...count ) {
				var tex = currentRenderTargets[i];
				if( tex != null && tex.t.setClearColor(color) ) {
					// update texture to use another clear value
					var prev = tex.t;
					tex.t = allocTexture(tex);
					@:privateAccess tex.t.clearColorChanges = prev.clearColorChanges;
					frame.toRelease.push(prev.res);
					Driver.createRenderTargetView(tex.t.res, null, tmp.renderTargets[i]);
				}
				frame.commandList.clearRenderTargetView(tmp.renderTargets[i], clear);
			}
		}
		if( depth != null || stencil != null )
			frame.commandList.clearDepthStencilView(tmp.depthStencils[0], depth != null ? (stencil != null ? BOTH : DEPTH) : STENCIL, (depth:Float), stencil);
	}

	function waitGpu() {
		Driver.signal(fence, fenceValue);
		fence.setEvent(fenceValue, fenceEvent);
		fenceEvent.wait(-1);
		fenceValue++;
	}

	override function resize(width:Int, height:Int)  {

		if( currentWidth == width && currentHeight == height )
			return;

		currentWidth = rtWidth = width;
		currentHeight = rtHeight = height;
		@:privateAccess defaultDepth.width = width;
		@:privateAccess defaultDepth.height = height;

		if( frame != null )
			flushFrame(true);

		waitGpu();

		for( f in frames ) {
			if( f.backBuffer.res != null )
				f.backBuffer.res.release();
			if( f.depthBuffer != null )
				f.depthBuffer.release();
		}

		Driver.resize(width, height, BUFFER_COUNT, R8G8B8A8_UNORM);

		renderTargetViews.clear();
		depthStenciViews.clear();

		for( i => f in frames ) {
			f.backBuffer.res = Driver.getBackBuffer(i);
			f.backBuffer.res.setName("Backbuffer#"+i);
			f.backBuffer.state = PRESENT;

			var desc = new ResourceDesc();
			var flags = new haxe.EnumFlags();
			desc.dimension = TEXTURE2D;
			desc.width = width;
			desc.height = height;
			desc.depthOrArraySize = 1;
			desc.mipLevels = 1;
			desc.sampleDesc.count = 1;
			desc.format = D24_UNORM_S8_UINT;
			desc.flags.set(ALLOW_DEPTH_STENCIL);
			tmp.heap.type = DEFAULT;

			tmp.clearValue.format = desc.format;
			tmp.clearValue.depth = 1;
			tmp.clearValue.stencil= 0;
			f.depthBuffer = Driver.createCommittedResource(tmp.heap, flags, desc, DEPTH_WRITE, tmp.clearValue);
			f.depthBuffer.setName("Depthbuffer#"+i);
		}

		beginFrame();
	}

	override function begin(frame:Int) {
	}

	override function isDisposed() {
		return hasDeviceError;
	}

	override function init( onCreate : Bool -> Void, forceSoftware = false ) {
		onContextLost = onCreate.bind(true);
		haxe.Timer.delay(onCreate.bind(false), 1);
	}

	override function getDriverName(details:Bool) {
		var desc = "DX12";
		if( details ) desc += " "+Driver.getDeviceName();
		return desc;
	}