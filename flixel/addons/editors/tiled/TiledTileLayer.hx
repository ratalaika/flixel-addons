package flixel.addons.editors.tiled;

import haxe.xml.Fast;
import flixel.addons.editors.tiled.TiledLayer.TiledLayerType;
import openfl.utils.ByteArray;
import flash.utils.Endian;

class TiledTileLayer extends TiledLayer
{
	public var x:Int;
	public var y:Int;
	public var width:Int;
	public var height:Int;
	public var tiles:Array<TiledTile>;
	
	public var encoding(get, null):String;
	public var csvData(get, null):String;
	public var tileArray(get, null):Array<Int>;
	
	private var xmlData:Fast;

	private static inline var BASE64_CHARS:String = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";
	
	public function new(source:Fast, parent:TiledMap)
	{
		super(source, parent);
		type = TiledLayerType.TILE;
		x = (source.has.x) ? Std.parseInt(source.att.x) : 0;
		y = (source.has.y) ? Std.parseInt(source.att.y) : 0;
		width = Std.parseInt(source.att.width);
		height = Std.parseInt(source.att.height);
		
		tiles = new Array<TiledTile>();
		
		// load tile GIDs
		xmlData = source.node.data;
		if (xmlData == null)
		{
			throw "Error loading TiledLayer level data";
		}
	}
	
	private function getByteArrayData():ByteArray
	{
		var result:ByteArray = null;

		if (encoding == "base64")
		{
			var chunk:String = xmlData.innerData;
			var compressed:Bool = false;

			result = base64ToByteArray(chunk);
			result.endian = Endian.LITTLE_ENDIAN;

			if (xmlData.has.compression)
			{
				switch(xmlData.att.compression)
				{
					case "zlib":
						compressed = true;
					default:
						throw "TiledLayer - data compression type not supported!";
				}
			}

			if (compressed)
			{
				#if (js && !format)
				throw "HTML5 doesn't support compressed data! Use Base64 (uncompressed) when you save the map or install the library 'format' and use it";
				#else
				result.uncompress();
				#end
			}
		}
		else
		{
			throw "Must use base64 encoding in order to get tileArray data.";
		}
		// Compressed or uncompressed, the endian must be little endian
		result.endian = Endian.LITTLE_ENDIAN;
		return result;
	}

	private static function base64ToByteArray(data:String):ByteArray
	{
		var output:ByteArray = new ByteArray();

		// initialize lookup table
		var lookup:Array<Int> = new Array<Int>();

		for (c in 0...BASE64_CHARS.length)
		{
			lookup[BASE64_CHARS.charCodeAt(c)] = c;
		}

		var i:Int = 0;
		while (i < data.length - 3)
		{
			// Ignore whitespace
			if (data.charAt(i) == " " || data.charAt(i) == "\n" || data.charAt(i) == "\r")
			{
				i++; continue;
			}

			// read 4 bytes and look them up in the table
			var a0:Int = lookup[data.charCodeAt(i)];
			var a1:Int = lookup[data.charCodeAt(i + 1)];
			var a2:Int = lookup[data.charCodeAt(i + 2)];
			var a3:Int = lookup[data.charCodeAt(i + 3)];

			// convert to and write 3 bytes
			if (a1 < 64)
			{
				output.writeByte((a0 << 2) + ((a1 & 0x30) >> 4));
			}
			if (a2 < 64)
			{
				output.writeByte(((a1 & 0x0f) << 4) + ((a2 & 0x3c) >> 2));
			}
			if (a3 < 64)
			{
				output.writeByte(((a2 & 0x03) << 6) + a3);
			}

			i += 4;
		}

		// Rewind & return decoded data
		output.position = 0;

		return output;
	}

	private function resolveTile(globalTileId:Int):Int
	{
		var tile:TiledTile = new TiledTile(globalTileId);

		var tilesetID:Int = tile.tilesetID;
		for (tileset in map.tilesets)
		{
			if (tileset.hasGid(tilesetID))
			{
				tiles.push(tile);
				return tilesetID;
			}
		}
		tiles.push(null);
		return 0;
	}

	/**
	 * Function that tries to resolve the tiles gid in the csv data.
	 * TODO: It fails because I can't find a function to parse an unsigned int from a string :(
	 * @param	csvData		The csv string to resolve
	 * @return	The csv string resolved
	 */
	private function resolveCsvTiles(csvData:String):String
	{
		var buffer:StringBuf = new StringBuf();
		var rows:Array<String> = csvData.split("\n");
		var values:Array<String>;
		for(row in rows) {
			values = row.split(",");
			var i:Int;
			for (v in values) {
				if (v == "") {
					continue;
				}
				i = Std.parseInt(v);
				buffer.add(resolveTile(i) + ",");
			}
			buffer.add("\n");
		}

		var result:String = buffer.toString();
		buffer = null;
		return result;
	}
	
	private function get_encoding():String
	{
		return encoding != null ? encoding : xmlData.att.encoding;
	}
	
	private function get_csvData():String
	{
		if (csvData == null)
		{
			if (xmlData.att.encoding == "csv")
			{
				csvData = StringTools.ltrim(xmlData.innerData);
			}
			else
			{
				throw "Must use CSV encoding in order to get CSV data.";
			}
		}
		return csvData;
	}

	private function get_tileArray():Array<Int>
	{
		if (tileArray == null)
		{
			var mapData:ByteArray = getByteArrayData();

			if (mapData == null)
			{
				throw "Must use Base64 encoding (with or without zlip compression) in order to get 1D Array.";
			}

			tileArray = new Array<Int>();

			while (mapData.position < mapData.length)
			{
				tileArray.push(resolveTile(mapData.readUnsignedInt()));
			}
		}

		return tileArray;
	}
}