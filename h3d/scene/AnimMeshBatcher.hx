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
	var