package hxd.fmt.fbx;
using hxd.fmt.fbx.Data;
import hxd.fmt.fbx.BaseLibrary;
import hxd.fmt.hmd.Data;

class HMDOut extends BaseLibrary {

	var d : Data;
	var dataOut : haxe.io.BytesOutput;
	var filePath : String;
	var tmp = haxe.io.Bytes.alloc(4);
	public var absoluteTexturePath : Bool;
	public var optimizeSkin = true;
	public var generateNormals = false;
	public var generateTangents = false;

	function int32tof( v : Int ) : Float {
		tmp.set(0, v & 0xFF);
		tmp.set(1, (v >> 8) & 0xFF);
		tmp.set(2, (v >> 16) & 0xFF);
		tmp.set(3, v >>> 24);
		return tmp.getFloat(0);
	}

	override function keepJoint(j:h3d.anim.Skin.Joint) {
		if( !optimizeSkin )
			return true;
		// remove these unskinned terminal bones if they are not named in a special manner
		if( ~/^Bip00[0-9] /.match(j.name) || ~/^Bone[0-9][0-9][0-9]$/.match(j.name) )
			return false;
		return true;
	}

	function buildTangents( geom : hxd.fmt.fbx.Geometry ) {
		var verts = geom.getVertices();
		var normals = geom.getNormals();
		var uvs = geom.getUVs();
		var index = geom.getIndexes();

		if ( index.vidx.length > 0 && uvs[0] == null )
			throw "Need UVs to build tangents";

		#if (hl && !hl_disable_mikkt && (haxe_ver >= "4.0"))
		var m = new hl.Format.Mikktspace();
		m.buffer = new hl.Bytes(8 * 4 * index.vidx.length);
		m.stride = 8;
		m.xPos = 0;
		m.normalPos = 3;
		m.uvPos = 6;

		m.indexes = new hl.Bytes(4 * index.vidx.length);
		m.indices = index.vidx.length;

		m.tangents = new hl.Bytes(4 * 4 * index.vidx.length);
		(m.tangents:hl.Bytes).fill(0,4 * 4 * index.vidx.length,0);
		m.tangentStride = 4;
		m.tangentPos = 0;

		var out = 0;
		for( i in 0...index.vidx.length ) {
			var vidx = index.vidx[i];
			m.buffer[out++] = verts[vidx*3];
			m.buffer[out++] = verts[vidx*3+1];
			m.buffer[out++] = verts[vidx*3+2];

			m.buffer[out++] = normals[i*3];
			m.buffer[out++] = normals[i*3+1];
			m.buffer[out++] = normals[i*3+2];
			var uidx = uvs[0].index[i];

			m.buffer[out++] = uvs[0].values[uidx*2];
			m.buffer[out++] = uvs[0].values[uidx*2+1];

			m.tangents[i<<2] = 1;

			m.indexes[i] = i;
		}

		m.compute();
		return m.tangents;
		#elseif (sys || nodejs)
		var tmp = Sys.getEnv("TMPDIR");
		if( tmp == null ) tmp = Sys.getEnv("TMP");
		if( tmp == null ) tmp = Sys.getEnv("TEMP");
		if( tmp == null ) tmp = ".";
		var fileName = tmp+"/mikktspace_data"+Date.now().getTime()+"_"+Std.random(0x1000000)+".bin";
		var outFile = fileName+".out";
		var outputData = new haxe.io.BytesBuffer();
		outputData.addInt32(index.vidx.length);
		outputData.addInt32(8);
		outputData.addInt32(0);
		outputData.addInt32(3);
		outputData.addInt32(6);
		for( i in 0...index.vidx.length ) {
			inline function w(v:Float) outputData.addFloat(v);
			var vidx = index.vidx[i];
			w(verts[vidx*3]);
			w(verts[vidx*3+1]);
			w(verts[vidx*3+2]);

			w(normals[i*3]);
			w(normals[i*3+1]);
			w(normals[i*3+2]);
			var uidx = uvs[0].index[i];

			w(uvs[0].values[uidx*2]);
			w(uvs[0].values[uidx*2+1]);
		}
		outputData.addInt32(index.vidx.length);
		for( i in 0...index.vidx.length )
			outputData.addInt32(i);
		sys.io.File.saveBytes(fileName, outputData.getBytes());
		var ret = try Sys.command("mikktspace",[fileName,outFile]) catch( e : Dynamic ) -1;
		if( ret != 0 ) {
			sys.FileSystem.deleteFile(fileName);
			throw "Failed to call 'mikktspace' executable required to generate tangent data. Please ensure it's in your PATH";
		}
		var bytes = sys.io.File.getBytes(outFile);
		var arr = [];
		for( i in 0...index.vidx.length*4 )
			arr[i] = bytes.getFloat(i << 2);
		sys.FileSystem.deleteFile(fileName);
		sys.FileSystem.deleteFile(outFile);
		return arr;
		#else
		throw "Tangent generation is not supported on this platform";
		return ([] : Array<Float>);
		#end
	}

	function updateNormals( g : Geometry, vbuf : hxd.FloatBuffer, idx : Array<Array<Int>> ) {
		var stride = g.vertexStride;
		var normalPos = 0;
		for( f in g.vertexFormat ) {
			if( f.name == "logicNormal" ) break;
			normalPos += f.format.getSize();
		}

		var points : Array<h3d.col.Point> = [];
		var pmap = [];
		for( vid in 0...g.vertexCount ) {
			var x = vbuf[vid * stride];
			var y = vbuf[vid * stride + 1];
			var z = vbuf[vid * stride + 2];
			var found = false;
			for( i in 0...points.length ) {
				var p = points[i];
				if( p.x == x && p.y == y && p.z == z ) {
					pmap[vid] = i;
					found = true;
					break;
				}
			}
			if( !found ) {
				pmap[vid] = points.length;
				points.push(new h3d.col.Point(x,y,z));
			}
		}
		var realIdx = new hxd.IndexBuffer();
		for( idx in idx )
			for( i in idx )
				realIdx.push(pmap[i]);

		var poly = new h3d.prim.Polygon(points, realIdx);
		poly.addNormals();

		for( vid in 0...g.vertexCount ) {
			var nid = pmap[vid];
			vbuf[vid*stride + normalPos] = poly.normals[nid].x;
			vbuf[vid*stride + normalPos + 1] = poly.normals[nid].y;
			vbuf[vid*stride + normalPos + 2] = poly.normals[nid].z;
		}
	}

	function buildGeom( geom : hxd.fmt.fbx.Geometry, skin : h3d.anim.Skin, dataOut : haxe.io.BytesOutput, genTangents : Bool ) {
		var g = new Geometry();

		var verts = geom.getVertices();
		var normals = geom.getNormals();
		var uvs = geom.getUVs();
		var colors = geom.getColors();
		var mats = geom.getMaterials();

		// remove empty color data
		if( colors != null ) {
			var hasData = false;
			for( v in colors.values )
				if( v < 0.99 ) {
					hasData = true;
					break;
				}
			if( !hasData )
				colors = null;
		}

		// generate tangents
		var tangents = genTangents ? buildTangents(geom) : null;

		// build format
		g.vertexFormat = [
			new GeometryFormat("position", DVec3),
		];
		if( normals != null )
			g.vertexFormat.push(new GeometryFormat("normal", DVec3));
		if( tangents != null )
			g.vertexFormat.push(new GeometryFormat("tangent", DVec3));
		for( i in 0...uvs.length )
			g.vertexFormat.push(new GeometryFormat("uv" + (i == 0 ? "" : "" + (i + 1)), DVec2));
		if( colors != null )
			g.vertexFormat.push(new GeometryFormat("color", DVec3));

		if( skin != null ) {
			if(fourBonesByVertex)
				g.props = [FourBonesByVertex];
			g.vertexFormat.push(new GeometryFormat("weights", DVec3));  // Only 3 weights are necessary even in fourBonesByVertex since they sum-up to 1
			g.vertexFormat.push(new GeometryFormat("indexes", DBytes4));
		}

		if( generateNormals )
			g.vertexFormat.push(new GeometryFormat("logicNormal", DVec3));

		var stride = 0;
		for( f in g.vertexFormat )
			stride += f.format.getSize();
		g.vertexStride = stride;
		g.vertexCount = 0;

		// build geometry
		var gm = geom.getGeomMatrix();
		var vbuf = new hxd.FloatBuffer();
		var ibufs = [];

		if( skin != null && skin.isSplit() ) {
			for( _ in skin.splitJoints )
				ibufs.push([]);
		}

		g.bounds = new h3d.col.Bounds();
		var tmpBuf = new hxd.impl.TypedArray.Float32Array(stride);
		var vertexRemap = new Array<Int>();
		var index = geom.getPolygons();
		var count = 0, matPos = 0, stri = 0;
		var