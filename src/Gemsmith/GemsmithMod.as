package Gemsmith 
{
	/**
	 * ...
	 * @author Chris
	 */
	
	import Bezel.Bezel;
	import Bezel.BezelMod;
	import Bezel.GCFW.GCFWBezel;
	import Bezel.Logger;
	import flash.display.MovieClip;
	
	public class GemsmithMod extends MovieClip implements BezelMod
	{
		
		public function get VERSION():String { return "1.14"; }
		public function get BEZEL_VERSION():String { return "1.1.2"; }
		public function get MOD_NAME():String { return "Gemsmith"; }
		
		private var gemsmith:Object;
		private var game:String;
		
		internal static var bezel:Bezel;
		internal static var logger:Logger;
		internal static var instance:GemsmithMod;
		internal static var gameObjects:Object;

		public static const GCFW_VERSION:String = "1.2.1a";
		public static const GCCS_VERSION:String = "1.0.6";
		
		public static var FIELD_WIDTH: Number;
		public static var FIELD_HEIGHT: Number;
		public static var WAVESTONE_WIDTH: Number;
		public static var TOP_UI_HEIGHT: Number;
		public static var TILE_SIZE: Number;
		
		public function GemsmithMod()
		{
			super();
			instance = this;
		}
		
		// This method binds the class to the game's objects
		public function bind(modLoader:Bezel, gObjects:Object):void
		{
			bezel = modLoader;
			logger = bezel.getLogger("Gemsmith");
			gameObjects = gObjects;
			if (bezel.mainLoader.gameClassFullyQualifiedName == "com.giab.games.gcfw.Main")
			{
				gemsmith = new GCFWGemsmith();
				initForGame("GCFW");
				gemsmith.formRecipeList();
			}
			else if(bezel.mainLoader.gameClassFullyQualifiedName == "com.giab.games.gccs.steam.Main")
			{
				gemsmith = new GCCSGemsmith();
				initForGame("GCCS");
				gemsmith.formRecipeList();
			}
		}
		
		public function unload():void
		{
			if (gemsmith != null)
			{
				gemsmith.unload();
				gemsmith = null;
			}
		}
		
		private function initForGame(game:String): void
		{
			this.game = game;
			if (game == "GCCS")
			{
				FIELD_WIDTH = 54;
				FIELD_HEIGHT = 32;
				WAVESTONE_WIDTH = 39;
				TOP_UI_HEIGHT = 53;
				TILE_SIZE = 17;
			}
			else
			{
				FIELD_WIDTH = 60;
				FIELD_HEIGHT = 38;
				WAVESTONE_WIDTH = 50;
				TOP_UI_HEIGHT = 8;
				TILE_SIZE = 28;
			}
		}
		
		public function letterToGemType(letter:String): int
		{
			if (this.game == "GCCS")
			{
				if (letter == "r")
					return gameObjects.constants.gemComponentType.CHAIN_HIT;
				else if(letter == "b")
					return gameObjects.constants.gemComponentType.BLOODBOUND;
				else if(letter == "o" || letter=="m")
					return gameObjects.constants.gemComponentType.MANA_LEECHING;
				else if(letter == "y" || letter == "k")
					return gameObjects.constants.gemComponentType.CRITHIT;
				else if(letter == "w")
					return gameObjects.constants.gemComponentType.POOLBOUND;
				else return gameObjects.constants.gemComponentType.CRITHIT
			}
			else if(this.game == "GCFW")
			{
				if (letter == "r")
					return gameObjects.constants.gemComponentType.BLEEDING;
				else if(letter == "b")
					return gameObjects.constants.gemComponentType.SLOWING;
				else if(letter == "o" || letter=="m")
					return gameObjects.constants.gemComponentType.MANA_LEECHING;
				else if(letter == "y" || letter == "k")
					return gameObjects.constants.gemComponentType.CRITHIT;
				else return gameObjects.constants.gemComponentType.CRITHIT
			}
			else
				return 0;
		}
		
		public function prettyVersion(): String
		{
			var version: String = 'v' + VERSION + ' for Bezel ';
			version += BEZEL_VERSION;
			return version;
		}
	}

}
