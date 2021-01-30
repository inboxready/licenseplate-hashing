package h3d.scene;

class AnimMeshBatchShader extends hxsl.Shader {
	static var SRC = {
		@param var animationMatrix : Mat4;

		@global var global : {
			@perObject var modelView : Mat4;
		};

		@input var input : {
			var normal : Vec3;
		};

		var relativePosition : Vec3;
		var transformedNormal : Vec3;
		function vertex() {
			relativePosition = relativePosition * animationMatrix.mat3x4();
			transformedNormal = (input.normal * animationMatrix.mat3() * global.modelView.mat3()).normalize();
		}
	};
}

class AnimMeshBatch extends MeshBatch {
	var copyObject : Object;
	var shader : AnimMeshBatchShader;

	public function new(primitive, material, copyObject, ?parent) {
		super(primitive, material, parent);
		shader = new AnimMeshBatchShader();
		material.mainPass.addShader(shader);
		this.copyObject = copyObject;
	}
	override function sync(ctx : RenderContext) {
		super.sync(ctx);
		shader.animationMatrix = copyObject.defaultTransform;
	}
}

class AnimMeshBatcher extends Object {
	var or