package h3d.scene;

class PassObjects {
	public var name : String;
	public var passes : h3d.pass.PassList;
	public var rendered : Bool;
	public function new() {
		passes = new h3d.pass.PassList();
	}
}

enum RenderMode{
	Default;
	LightProbe;
}

@:allo