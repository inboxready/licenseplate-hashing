
class DrawingTiles extends SampleApp {

	override function init() {
		super.init();

		var logo = hxd.Res.hxlogo.toTile();
		var normalmap = hxd.Res.normalmap.toTile();

		var hbox = new h2d.Flow(fui);
		hbox.horizontalSpacing = 10;

		// Bitmap renders a singular Tile
		new h2d.Bitmap(hxd.Res.hxlogo.toTile(), hbox);

		// TileGroup allows to batch-render multiple tiles.
		// Best performance ahieved when all Tiles are from same Texture.
		var tilegroup = new h2d.TileGroup(hbox);
		var tileSize = logo.width / 8;
		var tiles = logo.gridFlatten(tileSize);
		hxd.Math.shuffle(tiles);
		var i = 0;
		for ( y in 0...8 ) {
			for ( x in 0...8 ) {
				tilegroup.add(x * tileSize, y * tileSize, tiles[i++]);
				if (Math.random() > 0.7) {
					// TileGroup supports different texture sources.
					// but each texture swap causes new drawcall,
					// so it's adviced to use single texture for all group contents.
					tilegroup.addAlpha(x * tileSize, y * tileSize, 0.2, normalmap.sub((normalmap.width - tileSize) * Math.random(), (normalmap.height - tileSize) * Math.random(), tileSize, tileSize));
				}
			}
		}

		// SpriteBatch also allow to batch-render multiple tiles.
		// Compared to TileGroup - it's a dynamic tile geometry and reflushed to GPU every frame.
		// Same drawcall optimizations with unique texture count apply to SpriteBatch.
		var sprites = new h2d.SpriteBatch(null, hbox);
		// Causes containing sprites to receieve `update` calls.
		sprites.hasUpdate = true;
		// Tells SpriteBatch to calculate scale and rotation for sprites.
		// More CPU-intensive.
		sprites.hasRotationScale = true;
		tiles = logo.gridFlatten(tileSize);
		var i = 0;
		for ( y in 0...8 ) {
			for ( x in 0...8 ) {