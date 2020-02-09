package Gemsmith 
{
	/**
	 * ...
	 * @author Hellrage
	 */
	
	import flash.filesystem.File;
	import flash.filesystem.FileStream;
	import flash.filesystem.FileMode;
	
	public class Recipe 
	{
		//These would have public getters\setters anyways so I'm leaving them as public for now
		//Can refactor later if needed, it shouldn't break the consumer code
		public var name:String;
		public var filePath:String;
		public var instructions:Array;
		public var gradeIncrease:Number;
		public var value:Number;
		public var combines:Number;
		
		private static var _emptyRecipe:Recipe;
		
		public static function get emptyRecipe():Recipe 
		{
			return _emptyRecipe || new Recipe();
		}
		
		// Parses a recipe from a file with the given name
		// Returns a recipe Object that has an array of instuctions, cost multipliers, and a name
		public static function fromFile(filePath:String): Recipe
		{
	
			var file:File = new File(filePath);
			var stream:FileStream = new FileStream();
			var fileContents: String = "";
			try {
				stream.open(file, FileMode.READ);
				fileContents = stream.readUTFBytes(stream.bytesAvailable);
				stream.close();
			}
			catch(error:Error)
			{
				stream.close();
				Gemsmith.Gemsmith.logger.log("Recipe.fromFile", error.message);
				Gemsmith.Gemsmith.logger.log("Recipe.fromFile", "In file: " + filePath);
				return emptyRecipe;
			}
			var rex:RegExp = /[ \t]+/gim;
			fileContents = fileContents.replace(rex, '');
			var recipe:Recipe = new Recipe();
			recipe.name = file.name.substring(0, file.name.length - 4);
			recipe.filePath = filePath;
			recipe.instructions = new Array();
			for each(var equation: String in fileContents.split('\n'))
			{
				var components: Array = equation.split('+');
				// Only process gem combination expressions
				if(components.length != 2)
				{
					continue;
				}
				
				var lastDigits:RegExp = /[\d]*$/;
				var gl: int = int(((String)(components[0])).match(lastDigits)[0]);
				var gr: int = int(components[1]);
				recipe.instructions.push({left:gl, right:gr});
				if (Math.max(gl, gr) >= recipe.instructions.length)
				{
					recipe.name = "[Invalid!]" + recipe.name;
					recipe.instructions = [];
					Gemsmith.Gemsmith.logger.log("Recipe.fromFile", "Invalid equation: ")
					Gemsmith.Gemsmith.logger.log("Recipe.fromFile", equation)
					Gemsmith.Gemsmith.logger.log("Recipe.fromFile", "In file: " + filePath);
				}
			}
			recipe.calculateResultValues();
			return recipe;
		}
		
		// I'd make this private if I could, or implement a RecipeFactory(That'd have the same problemm, can't restrict the constructor)
		// I'd like to ensure that recipes can always be handled properly, even if made from invalid equations
		function Recipe() 
		{
			this.name = "No recipe";
			this.filePath = "";
			this.instructions = [];
			this.gradeIncrease = NaN;
			this.value = NaN;
			this.combines = 0;
		}
		
		// Takes a recipe and calculates the necessary values to later calculate total cost
		// Also calculates relative grade increase
		public function calculateResultValues(): void
		{
			
			var stepGrades: Array = new Array();
			var stepValues: Array = new Array();
			var stepCombines: Array = new Array();
			stepCombines[0] = 0;
			stepValues[0] = 1;
			stepGrades[0] = 1;
			var newGrade: Number = stepGrades[0];
			for each(var instr: Object in this.instructions)
			{
				newGrade = (stepGrades[instr.left] == stepGrades[instr.right]) ? (stepGrades[instr.left] + 1) : Math.max(stepGrades[instr.left], stepGrades[instr.right]);
				stepGrades.push(newGrade);
				stepValues.push(stepValues[instr.left] + stepValues[instr.right]);
				stepCombines.push(stepCombines[instr.left] + stepCombines[instr.right] + 1);
			}
			this.gradeIncrease = stepGrades.pop() - stepGrades[0];
			this.value = stepValues.pop();
			this.combines = stepCombines.pop();
		}
	}

}