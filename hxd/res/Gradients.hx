package hxd.res;
import hxd.fmt.grd.Data;

class Gradients extends Resource {
	var data : Data;

	// creates a texture for the specified "name" gradient
	public function toTexture(name : String, ?resolution = 256) : h3d.mat.Texture {
		var data = getData();
		return createTexture([data.get(name)], resolution);
	}

	// creates a texture for each gradient
	public function toTextureMap(?resolution = 256) : Map<String, h3d.mat.Texture> {
		var map  = new Map<String, h3d.mat.Texture>();
		var data = getData();
		for (d in data) map.set(d.name, createTexture([d], resolution));
		return map;
	}

	// all gradients are written into the same texture
	public function toTileMap(?resolution = 256) : Map<String, h2d.Tile> {
		var data  = getData();
		var grads = [for (d in data) d];
		var tex   = createTexture(grads, resolution);
		var tile  = h2d.Tile.fromTexture(tex);

		var map = new Map<String, h2d.Tile>();
		v