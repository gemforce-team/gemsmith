package Gemsmith 
{
	import Bezel.Bezel;
	import Bezel.BezelMod;
	import Bezel.GCFW.GCFWBezel;
	import Bezel.Logger;
	import flash.display.MovieClip;
	import flash.utils.getQualifiedClassName;
	/**
	 * ...
	 * @author Chris
	 */
	public class GemsmithMod extends MovieClip implements BezelMod
	{
		
		public function get VERSION():String { return "1.12"; }
		public function get BEZEL_VERSION():String { return "1.0.0"; }
		public function get MOD_NAME():String { return "Gemsmith"; }
		
		private var gemsmith:Object;
		
		internal static var bezel:Bezel;
		internal static var logger:Logger;
		internal static var instance:GemsmithMod;
		internal static var gameObjects:Object;

		public static const GCFW_VERSION:String = "1.2.1a";
		public static const GCCS_VERSION:String = "1.0.6";
		
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
			if (bezel.mainLoader is GCFWBezel)
			{
				gemsmith = new GCFWGemsmith();
			}
			else
			{
				gemsmith = new GCCSGemsmith();
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
		
		public function prettyVersion(): String
		{
			return 'v' + VERSION + ' for ' + (bezel.mainLoader is GCFWBezel) ? GCFW_VERSION : GCCS_VERSION;
		}
	}

}
