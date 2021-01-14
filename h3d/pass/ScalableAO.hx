package h3d.pass;

class ScalableAO extends h3d.pass.ScreenFx<h3d.shader.SAO> {

	public function new() {
		super(new h3d.shader.SAO());
	}

	public function apply( depthTexture : h