package h3d.prim;

class HMDModel extends MeshPrimitive {

	var data : hxd.fmt.hmd.Data.Geometry;
	var dataPosition : Int;
	var indexCount : Int;
	var indexesTriPos : Array<Int>;
	var lib : hxd.fmt.hmd.Library;
	var curMaterial : Int;
	var collider : h3d.col.Collider;
	var normalsRecomput