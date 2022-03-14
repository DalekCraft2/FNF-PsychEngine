package animateatlas;

/**
 * All data needed for the json importer + some extra for after parsing.
 * Stolen mostly from https://github.com/TomByrne/Starling-Extension-Adobe-Animate-Hx/blob/master/hx/src/starling/extensions/animate/AnimationAtlasData.hx
 */
typedef AnimationData =
{
	?animation:SymbolData,
	?symbolDictionary:
		{
			symbols:Array<SymbolData>
		},
	?metadata:
		{
			?framerate:Null<Int>
		}
}

typedef AtlasData =
{
	?atlas:
		{
			sprites:Array<SpriteDummy>
		},
	?meta:
		{
			app:String,
			version:String,
			image:String,
			format:String,
			size:{w:Int, h:Int},
			scale:String,
		}
}

typedef SpriteDummy =
{
	sprite:SpriteData
}

typedef SpriteData =
{
	name:String,
	x:Int,
	y:Int,
	w:Int,
	h:Int,
	rotated:Bool
}

typedef SymbolData =
{
	?name:String,
	symbolName:String,
	?timeline:SymbolTimelineData
}

typedef SymbolTimelineData =
{
	?sortedForRender:Bool,
	layers:Array<LayerData>
}

typedef LayerData =
{
	layerName:String,
	frames:Array<LayerFrameData>,
	frameMap:Map<Int, LayerFrameData>
}

typedef LayerFrameData =
{
	index:Int,
	?name:String,
	duration:Int,
	elements:Array<ElementData>
}

typedef ElementData =
{
	?atlasSpriteInstance:Dynamic,
	?symbolInstance:SymbolInstanceData
}

typedef SymbolInstanceData =
{
	symbolName:String,
	instanceName:String,
	bitmap:BitmapPosData,
	symbolType:String,
	transformationPoint:PointData,
	matrix3D:Matrix3DData,
	?decomposedMatrix:Decomposed3DData,
	?color:ColorData,

	?loop:String,
	firstFrame:Int,
	?filters:FilterData
}

typedef ColorData =
{
	mode:String,

	?redMultiplier:Float,
	?greenMultiplier:Float,
	?blueMultiplier:Float,
	?alphaMultiplier:Float,
	?redOffset:Float,
	?greenOffset:Float,
	?blueOffset:Float,
	?alphaOffset:Float
}

typedef BitmapPosData =
{
	name:String,
	position:PointData,
}

typedef PointData =
{
	x:Int,
	y:Int
}

typedef Matrix3DData =
{
	m00:Float,
	m01:Float,
	m02:Float,
	m03:Float,
	m10:Float,
	m11:Float,
	m12:Float,
	m13:Float,
	m20:Float,
	m21:Float,
	m22:Float,
	m23:Float,
	m30:Float,
	m31:Float,
	m32:Float,
	m33:Float,
}

// tryna add more support gimme a sec
typedef FilterData =
{
	?blurFilter:
		{
			blurX:Float,
			blurY:Float,
			quality:Int
		},

	?glowFilter:
		{
			blurX:Float,
			blurY:Float,
			color:Int,
			alpha:Int,
			quality:Int,
			strength:Int,
			knockout:Bool,
			inner:Bool
		}
}

typedef Decomposed3DData =
{
	position:
	{
		x:Float, y:Float, z:Float
	},
	rotation:
	{
		x:Float, y:Float, z:Float
	},
	scaling:
	{
		x:Float, y:Float, z:Float
	},
}
