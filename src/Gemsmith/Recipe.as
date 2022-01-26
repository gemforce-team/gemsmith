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
		public var type:String;
		public var seedGems:Object;
		public var baseGem:int;
		
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
				GemsmithMod.logger.log("Recipe.fromFile", error.message);
				GemsmithMod.logger.log("Recipe.fromFile", "In file: " + filePath);
				return emptyRecipe;
			}
			var rex:RegExp = /[ \t]+/gim;
			fileContents = fileContents.replace(rex, '');
			var recipe:Recipe = new Recipe();
			recipe.name = file.name.substring(0, file.name.length - 4);
			recipe.filePath = filePath;
			recipe.instructions = new Array();
			
			var equationsIndex: Number = fileContents.indexOf("Equations:");
			if (equationsIndex == -1)
			{
				recipe.type = "Spec";
				recipe.seedGems = new Object();
				equationsIndex = fileContents.indexOf("equations:") + 12;
				fileContents = fileContents.substring(equationsIndex);
				equationsIndex = fileContents.indexOf("equations:") + 12;
				fileContents = fileContents.substring(0, equationsIndex);
			}
			else
			{
				fileContents = fileContents.substring(equationsIndex + 12);
			}
			var equations: Array = fileContents.split(/(\r\n|\r|\n)/);
			
			var letter: String;
			for(var line: String in equations)
			{
				var equation: String = equations[line];
				if (equation.indexOf('=') == -1)
					continue;
					
				var valueDataEnd:int = equation.lastIndexOf(')');
				if (valueDataEnd > 0)
					equation  = equation.substring(valueDataEnd + 1);
					
				var components: Array;
					
				var opIndex: Number = equation.split('=')[0];
				equation = equation.split('=')[1];
				if (recipe.type == "Combine")
				{
					if (equation.indexOf("g1") != -1)
						if (opIndex == 0)
						{
							letter = equation.split("g1")[1].substr(0, 1);
							recipe.baseGem = GemsmithMod.instance.letterToGemType(letter);
							continue;
						}
						else
							break;
				}
				else if (recipe.type == "Spec")
				{
					if (equation.indexOf("g1") != -1)
					{
						letter = equation.split("g1")[1].substr(0, 1);
						recipe.seedGems[opIndex] = GemsmithMod.instance.letterToGemType(letter);
						if ((letter == "y") || (letter=="o"))
							recipe.baseGem = recipe.seedGems[opIndex];
						continue;
					}
				}
				
				components = equation.split('+');
				
				var lastDigits:RegExp = /[\d]*$/;
				var gl: Number = Number(((String)(components[0])).match(lastDigits)[0]);
				var gr: Number = Number(components[1]);
				recipe.instructions[opIndex] = {left:gl, right:gr};
				if (Math.max(gl, gr) >= (Number)(equation))
				{
					recipe.name = "[Invalid!]" + recipe.name;
					GemsmithMod.logger.log("Recipe.fromFile", "Invalid equation: ");
					GemsmithMod.logger.log("Recipe.fromFile", equation[equation]);
					GemsmithMod.logger.log("Recipe.fromFile", "gl: " + gl + "gr: " + gr);
					GemsmithMod.logger.log("Recipe.fromFile", "Instruction count: " + recipe.instructions.length);
					GemsmithMod.logger.log("Recipe.fromFile", "In file: " + filePath);
					recipe.instructions = [];
					break;
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
			this.type = "Combine";
			this.filePath = "";
			this.instructions = [];
			this.gradeIncrease = NaN;
			this.value = NaN;
			this.combines = 0;
			this.baseGem = -1;
		}
		
		// Takes a recipe and calculates the necessary values to later calculate total cost
		// Also calculates relative grade increase
		public function calculateResultValues(): void
		{
			
			var stepGrades: Array = new Array();
			var stepValues: Array = new Array();
			var stepCombines: Array = new Array();
			if (this.type == "Spec")
			{
				for (var step: String in this.seedGems)
				{
					stepCombines[step] = 0;
					stepValues[step] = 1;
					stepGrades[step] = 1;
				}
			}
			stepCombines[0] = 0;
			stepValues[0] = 1;
			stepGrades[0] = 1;
			var newGrade: Number = stepGrades[0];
			var instrindex: String;
			for(instrindex in this.instructions)
			{
				var instr: Object = this.instructions[instrindex];
				newGrade = (stepGrades[instr.left] == stepGrades[instr.right]) ? (stepGrades[instr.left] + 1) : Math.max(stepGrades[instr.left], stepGrades[instr.right]);
				stepGrades[instrindex] = newGrade;
				stepValues[instrindex] = stepValues[instr.left] + stepValues[instr.right];
				stepCombines[instrindex] = stepCombines[instr.left] + stepCombines[instr.right] + 1;
			}
			this.gradeIncrease = stepGrades[instrindex] - stepGrades[0];
			this.value = stepValues[instrindex];
			this.combines = stepCombines[instrindex];
		}
	}

}