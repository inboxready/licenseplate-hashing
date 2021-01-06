package h3d.pass;

class CascadeShadowMap extends DirShadowMap {

	var cshader : h3d.shader.CascadeShadow;
	var lightCameras : Array<h3d.Camera> = [];
	var currentCascadeIndex = 0;

	public var pow : Float = 1.0;
	public var firstCascadeSize : Float = 10.0;
	public var castingMaxDist : Float = 0.0;
	public var cascade(default, set) = 1;
	public function set_cascade(v) {
		cascade = v;
		lightCameras = [];
		for ( i in 0...cascade ) {
			lightCameras.push(new h3d.Camera());
			lightCameras[i].orthoBounds = new h3d.col.Bounds();
		}
		return cascade;
	}
	public var debugShader : Bool = false;

	static var debugColors = [0xff0000, 0x00ff00, 0x0000ff, 0xffff00, 0x00ffff, 0xff00ff, 0x000000];

	public function new( light : h3d.scene.Light ) {
		super(light);
		format = R32F;
		shader = dshader = cshader = new h3d.shader.CascadeShadow();
	}

	public override function getShadowTex() {
		return cshader.shadowMap;
	}

	public function getShadowTextures() {
		return cshader.cascadeShadowMaps;
	}

	function computeNearFar( i : Int ) {
		var min = minDist < 0.0 ? ctx.camera.zNear : minDist;
		var max = maxDist < 0.0 ? ctx.camera.zFar : maxDist;
		if ( i == 0 ) {
			return {near : min, far : min + firstCascadeSize};
		}
		var step = (max - min - firstCascadeSize) / (cascade - 1);
		var near = min + firstCascadeSize + hxd.Math.pow((i - 1) / (cascade - 1), pow) * step;
		var far = min + firstCascadeSize + hxd.Math.pow(i / (cascade - 1), pow) * step;
		return {near : near, far : far};
	}

	public function updateCascadeBounds( camera : h3d.Camera ) {
		var bounds = camera.orthoBounds;

		var shadowNear = hxd.Math.POSITIVE_INFINITY;
		var shadowFar = hxd.Math.NEGATIVE_INFINITY;
		var corners = lightCamera.getFrustumCorners();
		for ( corner in corners ) {
			corner.transform(ctx.camera.mcam);
			shadowNear = hxd.Math.min(shadowNear, corner.z / corner.w);
			shadowFar = hxd.Math.max(shadowFar, corner.z / corner.w);
		}
		for ( i in 0...cascade - 1 ) {
			var cascadeBounds = new h3d.col.Bounds();
			function addCorner(x,y,d) {
				var pt = ctx.camera.unproject(x,y,ctx.camera.distanceToDepth(d)).toPoint();
				pt.transform(camera.mcam);
				cascadeBounds.addPos(pt.x, pt.y, pt.z);
			}
			function addCorners(d) {
				addCorner(-1,-1,d);
				addCorner(-1,1,d);
				addCorner(1,-1,d);
				addCorner(1,1,d);
			}

			var nearFar = computeNearFar(i);
			addCorners(nearFar.near);
			addCorners(nearFar.far);
			// Increasing z range has no effect on resolution, only on depth precision.
			cascadeBounds.zMax = lightCamera.orthoBounds.zMax;
			cascadeBounds.zMin = lightCamera.orthoBounds.zMin;
			lightCameras[i].orthoBounds = cascadeBounds;
		}
		lightCameras[cascade - 1].orthoBounds = lightCamera.orthoBounds.clone();
	}

	override function setGlobals() {
		super.setGlobals();
		cameraViewProj = getCascadeProj(currentCascadeIndex);
	}

	function getCascadeProj(i:Int) {
		return lightCameras[i].m;
	}

	function syncCascadeShader(textures : Array<h3d.mat.Texture>) {
		cshader.DEBUG = debugShader;
		for ( i in 0...cascade ) {
			var c = cascade - 1 - i;
			cshader.cascadeShadowMaps[c] = textures[i];
			cshader.cascadeProjs[c] = lightCameras[i].m;
			if ( debugShader )
				cshader.cascadeDebugs[c] = h3d.Vector.fromColor(debugColors[i]);
			cshader.cascadeBias[c] = Math.pow(computeNearFar(i).far / computeNearFar(0).far, 1.2) * bias;
		}
		cshader.CASCADE_COUNT = cascade;
		cshader.shadowBias = bias;
		cshader.shadowPower = power;
		cshader.shadowProj = getShadowProj();

		//ESM
		cshader.USE_ESM = samplingKind == ESM;
		cshader.shadowPower = power;

		// PCF
		cshader.USE_PCF = samplingKind == PCF;
		cshader.shadowRes.set(textures[0].width,textures[0].height);
		cshader.pcfScale = pcfScale;
		cshader.pcfQuality = pcfQuality;
	}

	override function draw( passes, ?sort ) {
		if( !enabled )
			return;

		if( !filterPasses(passes) )
			return;

		if( mode != Mixed || ctx.computingStatic ) {
			var ct = ctx.camera.target;
			var slight = light == null ? ctx.lightSystem.shadowLight : light;
