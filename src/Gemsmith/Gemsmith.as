package Gemsmith
{
	import flash.display.MovieClip;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.events.KeyboardEvent;
	import flash.globalization.DateTimeFormatter;

	// We extend MovieClip so that flash.display.Loader accepts our class
	// The loader also requires a parameterless constructor (AFAIK), so we also have a .Bind method to bind our class to the game
	public class Gemsmith extends MovieClip
	{
		
		private var core:Object;/*IngameCore*/
		
		private var cnt:Object;/*CntIngame*/
		
		private var GV:Object;/*GV*/
		
		private var SB:Object;/*SB*/

		private var recipes:Array;

		private var currentRecipeIndex:int;

		private var configuration:Object;

		private var defaultHotkeys:Object;

		private var logFile:File;

		private var logStream:FileStream;
		
		// Parameterless constructor for flash.display.Loader
		public function Gemsmith()
		{
			super();
			PrepareFoldersAndLog();
			this.recipes = FormRecipeList();
			this.configuration = LoadConfigurationOrDefault();
			this.defaultHotkeys = CreateDefaultConfiguration().Hotkeys;
			
			UglyLog("Gemsmith", "Gemsmith initialized!");
		}
		
		// This method binds the class to the game's objects
		public function Bind(pCore:Object/*IngameCore*/, pCnt:Object/*CntIngame*/, gv:Object/*GV*/, sb:Object/*SB*/) : Gemsmith
		{
			this.core = pCore;
			this.cnt = pCnt;
			this.SB = sb;
			this.GV = gv;
			UglyLog("Gemsmith", "Gemsmith bound to game's objects!");
			return this;
		}
		
		// UglyLog is ugly because I open, write, close the stream every time this method is called
		// This is to guarantee that the messages arrive at the log in case of an uncaught exception
		private function UglyLog(source:String, message:String): void
		{
			logStream.open(logFile, FileMode.APPEND);
			var df:DateTimeFormatter = new DateTimeFormatter("");
			df.setDateTimePattern("yyyy-MM-dd HH:mm:ss");
			logStream.writeUTFBytes(df.format(new Date()) + "\t[" + source.substring(0,10) + "]:\t" + message + "\r\n");
			logStream.close();
		}

		// Populates the recipe array with recipes from the respective folder
		private function FormRecipeList(): Array
		{
			var newRecipes: Array = new Array();
			var recipesFolder:File = File.applicationStorageDirectory.resolvePath("Gemsmith/recipes");
			
			var fileList: Array = recipesFolder.getDirectoryListing();
			for(var f:int = 0; f < fileList.length; f++)
			{
				if(fileList[f].name.substring(fileList[f].name.length-4, fileList[f].name.length) == ".txt")
					newRecipes.push(LoadRecipeFromFile(fileList[f].name));
			}
			UglyLog("FormRecipeList", "Found " + newRecipes.length + " recipe files.");
			if (newRecipes.length == 0)
			{
				this.currentRecipeIndex = -1;
			}
			else
			{
				this.currentRecipeIndex = 0;
			}
			return newRecipes;
		}

		private function LoadConfigurationOrDefault(): Object
		{
			var configFile:File = File.applicationStorageDirectory.resolvePath("Gemsmith/Gemsmith_config.json");
			var configStream:FileStream = new FileStream();
			var config:Object = null;
			var configJSON:String = null;

			if(!configFile.exists)
			{
				config = CreateDefaultConfiguration();
				configJSON = JSON.stringify(config, null, 2);
				configStream.open(configFile, FileMode.WRITE);
				configStream.writeUTFBytes(configJSON);
				configStream.close();
			}
			else
			{
				try
				{
					configStream.open(configFile, FileMode.READ);
					configJSON = configStream.readUTFBytes(configStream.bytesAvailable);
					config = JSON.parse(configJSON);
					
					UglyLog("LoadConfiguration", "Loaded existing configuration");
				}
				catch(error:Error)
				{
					config = CreateDefaultConfiguration();
					UglyLog("LoadConfiguration", error.message);
					UglyLog("LoadConfiguration", "Reset to defaults");
				}
				configStream.close();

				if(config == null || config["Hotkeys"] == null)
				{
					config = CreateDefaultConfiguration();
					UglyLog("LoadConfiguration", "Configuration was invalid for some reason, reset to defaults");
				}
			}
			return config;
		}

		private function CreateDefaultConfiguration(): Object
		{
			var config:Object = new Object();
			config["Hotkeys"] = new Object();
			config["Hotkeys"]["Throw gem bombs"] = 66;
			config["Hotkeys"]["Build tower"] = 84;
			config["Hotkeys"]["Build lantern"] = 76;
			config["Hotkeys"]["Build pylon"] = 80;
			config["Hotkeys"]["Build trap"] = 82;
			config["Hotkeys"]["Build wall"] = 87;
			config["Hotkeys"]["Combine gems"] = 71;
			config["Hotkeys"]["Switch time speed"] = 81;
			config["Hotkeys"]["Pause time"] = 32;
			config["Hotkeys"]["Start next wave"] = 78;
			config["Hotkeys"]["Destroy gem for mana"] = 88;
			config["Hotkeys"]["Drop gem to inventory"] = 9;
			config["Hotkeys"]["Duplicate gem"] = 68;
			config["Hotkeys"]["Upgrade gem"] = 85;
			config["Hotkeys"]["Show/hide info panels"] = 190;
			config["Hotkeys"]["Cast freeze strike spell"] = 49;
			config["Hotkeys"]["Cast whiteout strike spell"] = 50;
			config["Hotkeys"]["Cast ice shards strike spell"] = 51;
			config["Hotkeys"]["Cast bolt enhancement spell"] = 52;
			config["Hotkeys"]["Cast beam enhancement spell"] = 53;
			config["Hotkeys"]["Cast barrage enhancement spell"] = 54;
			config["Hotkeys"]["Create Critical Hit gem"] = 100;
			config["Hotkeys"]["Create Mana Leeching gem"] = 101;
			config["Hotkeys"]["Create Bleeding gem"] = 102;
			config["Hotkeys"]["Create Armor Tearing gem"] = 97;
			config["Hotkeys"]["Create Poison gem"] = 98;
			config["Hotkeys"]["Create Slowing gem"] = 99;
			config["Hotkeys"]["Gemsmith: Cycle selected recipe left"] = 33;
			config["Hotkeys"]["Gemsmith: Perform combine"] = 36;
			config["Hotkeys"]["Gemsmith: Cycle selected recipe right"] = 34;
			config["Hotkeys"]["Up arrow function"] = 38;
			config["Hotkeys"]["Down arrow function"] = 40;
			config["Hotkeys"]["Left arrow function"] = 37;
			config["Hotkeys"]["Right arrow function"] = 39;

			return config;
		}

		// A placeholder method to later implement config "upgrading" when a new version adds some values
		private function UpdateConfig(config:Object) : Object
		{
			for(var name:String in this.defaultHotkeys)
			{
				if(!config["Hotkeys"][name])
					config["Hotkeys"][name] = this.defaultHotkeys[name];
			}
			return config;
		}

		public function CycleSelectedRecipe(increment:int): void
		{
			if(this.currentRecipeIndex == -1)
				return;
			this.currentRecipeIndex += increment;
			if(this.currentRecipeIndex < 0)
				this.currentRecipeIndex = recipes.length - 1;
			else if(this.currentRecipeIndex > recipes.length - 1)
				this.currentRecipeIndex = 0;
			var gem:Object/*Gem*/ = this.core.controller.getGemUnderPointer(false);
			if(gem != null)
			{
				this.core.infoPanelRenderer2.renderInfoPanelGem(gem, gem.containingBuilding);
			}
		}

		// Main method, this is called when pressing the hotkey
		// Handles gems in any slot, takes care of inserting it back into buildings
		public function CastCombineOnMouse(): void
		{
			if(this.currentRecipeIndex == -1)
			{
				SB.playSound("sndalert");
				GV.vfxEngine.createFloatingText4(GV.main.mouseX,GV.main.mouseY < 60?Number(GV.main.mouseY + 30):Number(GV.main.mouseY - 20),"No recipe selected!",16768392,14,"center",Math.random() * 3 - 1.5,-4 - Math.random() * 3,0,0.55,12,0,1000);
				return;
			}
			
			// ACTIONSTATUS enums are sadly not available yet
			if(this.core.actionStatus == 106)
			{
				this.core.controller.deselectEverything(true,false);
			}

			try
			{
				// ACTIONSTATUS enums are sadly not available yet
				if(GV.ingameCore.actionStatus < 300 || GV.ingameCore.actionStatus >= 600)
				{
					var gem:Object/*Gem*/ = this.core.controller.getGemUnderPointer(false);
					if(gem != null)
					{
						// First check if we have enough mana for it 
						var recipe: Object = this.recipes[this.currentRecipeIndex];
						var combineCost: Number = TotalCombineCostCurrent(gem);
						if(this.core.getMana() >= combineCost)
						{
							var resultingGem:Object/*Gem*/ = null;
							var invSlot:int = this.core.inventorySlots.indexOf(gem);
							if(invSlot != -1)
							{
								resultingGem = VirtualCombineGem(recipe, gem);
								this.core.inventorySlots[invSlot] = null;
								this.core.controller.placeGemIntoSlot(resultingGem, invSlot);
							}
							else if(this.core.gemInEnragingSlot == gem)
							{
								resultingGem = VirtualCombineGem(recipe, gem);
								this.core.cnt.cntGemInEnragingSlot.removeChild(gem.mc);

								this.core.gemInEnragingSlot = null;
								this.core.inputHandler.insertGemToEnragingSlot(resultingGem);
								GV.ingameAchiCtrl.checkAchi(117,true,true);
							}
							else
							{
								var selectedBuilding:Object = null;
								if(this.core.selectedTower != null)
								{
									selectedBuilding = this.core.selectedTower;
								}
								else if(this.core.selectedTrap != null)
								{
									this.core.selectedTrap.mc.cnt.removeChild(this.core.selectedTrap.insertedGem.mc);
									selectedBuilding = this.core.selectedTrap;
								}
								else if(this.core.selectedAmplifier != null)
								{
									selectedBuilding = this.core.selectedAmplifier;
								}
								else if(this.core.selectedLantern != null)
								{
									selectedBuilding = this.core.selectedLantern;
								}

								if(selectedBuilding != null)
								{
									resultingGem = VirtualCombineGem(recipe, gem);

									this.core.spellCaster.cnt.cntGemsInInventory.removeChild(selectedBuilding.insertedGem.mc);
									this.core.spellCaster.cnt.cntGemsInTowers.removeChild(selectedBuilding.insertedGem.mc);
									this.core.spellCaster.cnt.cntDraggedGem.removeChild(selectedBuilding.insertedGem.mc);
									
									selectedBuilding.removeGem();
									selectedBuilding.insertGem(resultingGem);
								}
								else
								{
									SB.playSound("sndalert");
									GV.vfxEngine.createFloatingText4(GV.main.mouseX,GV.main.mouseY < 60?Number(GV.main.mouseY + 30):Number(GV.main.mouseY - 20),"Can't find where the gem is!",16768392,20,"center",Math.random() * 3 - 1.5,-4 - Math.random() * 3,0,0.55,12,0,1000);
									return;
								}                          
							}
							// Check that there wasn't an exception
							if(gem != resultingGem)
								this.core.changeMana(-combineCost, false, true);
							this.core.controller.deselectEverything(true,true);
							SB.playSound("sndgemcombined");
						}
						else
						{
							SB.playSound("sndalert");
							GV.vfxEngine.createFloatingText4(GV.main.mouseX,GV.main.mouseY < 60?Number(GV.main.mouseY + 30):Number(GV.main.mouseY - 20),"Not enough mana",16768392,12,"center",Math.random() * 3 - 1.5,-4 - Math.random() * 3,0,0.55,12,0,1000);
							return;
						}
					}
					else
					{
						SB.playSound("sndalert");
						GV.vfxEngine.createFloatingText4(GV.main.mouseX,GV.main.mouseY < 60?Number(GV.main.mouseY + 30):Number(GV.main.mouseY - 20),"No gem under cursor",16768392,12,"center",Math.random() * 3 - 1.5,-4 - Math.random() * 3,0,0.55,12,0,1000);
						return;
					}
				}
			}
			catch(error:Error)
			{
				// TODO handle this exception wrt the gem
				UglyLog("CastCombineOnMouse", error.message);
				SB.playSound("sndalert");
				GV.vfxEngine.createFloatingText4(GV.main.mouseX,GV.main.mouseY < 60?Number(GV.main.mouseY + 30):Number(GV.main.mouseY - 20),"Caught an exception!",16768392,20,"center",Math.random() * 3 - 1.5,-4 - Math.random() * 3,0,0.55,12,0,1000);
				return;
			}
		}

		// Worker method, this bypasses the game's tracking of mana expenditure
		// Takes a recipe and performs the combine without using any inventory slots
		private function PerformCombineFromRecipe(recipe: Object, sourceGem:Object/*Gem*/): Object
		{
			var resultingGem:Object = null;
			var localInstructions: Array = recipe.Instructions;
			
			if(sourceGem == null)
			{
				return resultingGem;
			}
			var virtualInv: Array = new Array();
			virtualInv[0] = sourceGem;
			try 
			{
				// We're handling mana expenditure stats ourselves
				var sourceCombiningCost: Number = sourceGem.combinationManaValue.g();
				var sourceComponentCosts: Array = new Array(0, 0, 0, 0, 0, 0);
				for(var c: int = 0; c < 6; c++)
					sourceComponentCosts[c] = sourceGem.manaValuesByComponent[c].g();

				// Arrays to hold the step-by-step costs, these are filled as we perform the combine
				var stepCombiningCost: Array = new Array();
				var stepComponentCosts: Array = new Array();
				stepCombiningCost.push(sourceCombiningCost);
				stepComponentCosts.push(sourceComponentCosts.concat());

				for each(var instr: Object in localInstructions)
				{
					var res:Object = this.core.spellCaster.combineGems(virtualInv[instr.left], virtualInv[instr.right], true, true, false);
					res.kills.s(Math.round(res.kills.g() / 2));
					res.hits.s(Math.round(res.hits.g() / 2));
					res.manaLeeched = res.manaLeeched / 2;
					virtualInv.push(res);

					// Now we fill in the mana expenditure values
					stepCombiningCost.push(stepCombiningCost[instr.left] + stepCombiningCost[instr.right] + this.core.gemCombiningManaCost.g());
					stepComponentCosts.push(AddByComponentCosts(stepComponentCosts[instr.left], stepComponentCosts[instr.right]));
				}

				resultingGem = virtualInv.pop();
				var totalCombiningCost: Number = stepCombiningCost.pop();
				
				// We're handling stats ourselves
				resultingGem.combinationManaValue.s(totalCombiningCost);

				this.core.spellCaster.stats.spentManaOnCombinationCost += totalCombiningCost - sourceCombiningCost;

				var resultingComponentCosts: Array = stepComponentCosts.pop();
				this.core.spellCaster.stats.spentManaOnBleedingGem += resultingComponentCosts[2] - sourceComponentCosts[2];
				this.core.spellCaster.stats.spentManaOnCritHitGem += resultingComponentCosts[0] - sourceComponentCosts[0];
				this.core.spellCaster.stats.spentManaOnPoisonGem += resultingComponentCosts[4] - sourceComponentCosts[4];
				this.core.spellCaster.stats.spentManaOnSlowingGem += resultingComponentCosts[5] - sourceComponentCosts[5];
				this.core.spellCaster.stats.spentManaOnManaLeechingGem += resultingComponentCosts[1] - sourceComponentCosts[1];
				this.core.spellCaster.stats.spentManaOnArmorTearingGem += resultingComponentCosts[3] - sourceComponentCosts[3];
				
				this.core.spellCaster.stats.highestGradeGemCreated = Math.max(resultingGem.grade.g() + 1,this.core.spellCaster.stats.highestGradeGemCreated);
				this.core.stats.gemHighestMaxDamage = Math.max(this.core.stats.gemHighestMaxDamage,resultingGem.sd2_CompNumMod.damageMax.g());
			 
				return resultingGem;
			}
			catch(error: Error) {
				SB.playSound("sndalert");
				GV.vfxEngine.createFloatingText4(GV.main.mouseX,GV.main.mouseY < 60?Number(GV.main.mouseY + 30):Number(GV.main.mouseY - 20),"An error occured!",16768392,12,"center",Math.random() * 3 - 1.5,-4 - Math.random() * 3,0,0.55,12,0,1000);
				UglyLog("PerformCombineFromInstructions", error.message);
				return sourceGem;
			}
			return sourceGem;
		}

		// This is the main method, takes a gem, carefully performs the combine, returns the new gem
		// Also handles gem bitmap creation
		private function VirtualCombineGem(recipe: Object, gem:Object/*Gem*/): Object
		{
			// Remember the modified range
			var vRangeRatio:Number = NaN;
			var vRange4:Number = NaN;
			var vRange5:Number = NaN;
			vRangeRatio = gem.rangeRatio.g();
			vRange4 = gem.sd4_IntensityMod.range.g();
			vRange5 = gem.sd5_EnhancedOrTrapOrLantern.range.g();
			gem.rangeRatio.s(1);
			gem.sd4_IntensityMod.range.s(vRange4 / vRangeRatio * gem.rangeRatio.g());
			gem.sd5_EnhancedOrTrapOrLantern.range.s(vRange5 / vRangeRatio * gem.rangeRatio.g());

			// In case of failure we just return the source gem
			var resultingGem:Object = PerformCombineFromRecipe(recipe, gem) || gem;
			if(this.core.gems.indexOf(gem) >= 0)
				this.core.gems.splice(this.core.gems.indexOf(gem), 1);
			resultingGem.recalculateSds();
			GV.gemBitmapCreator.giveGemBitmaps(resultingGem);
			this.core.gems.push(resultingGem);

			// Restore the modified range
			vRange4 = resultingGem.sd4_IntensityMod.range.g();
			vRange5 = resultingGem.sd5_EnhancedOrTrapOrLantern.range.g();
			resultingGem.rangeRatio.s(vRangeRatio);
			resultingGem.sd4_IntensityMod.range.s(vRange4 * resultingGem.rangeRatio.g());
			resultingGem.sd5_EnhancedOrTrapOrLantern.range.s(vRange5 * resultingGem.rangeRatio.g());

			return resultingGem;
		}
		
		// A helper method for summing two gems' component costs
		private function AddByComponentCosts(cc1: Array, cc2: Array): Array
		{
			var cc3: Array = new Array(0, 0, 0, 0, 0, 0);/*Gem component costs*/
			for(var c: int = 0; c < 6; c++)
				cc3[c] = cc1[c]+cc2[c];
			return cc3;
		}

		public function TotalCombineCost(recipe: Object, sourceGem:Object/*Gem*/): Number
		{
			return sourceGem.cost.g() * (recipe.Value - 1) + this.core.gemCombiningManaCost.g() * recipe.Combines;
		}

		// Takes a recipe and calculates the necessary values to later calculate total cost
		// Also calculates relative grade increase
		private function SetCosts(recipe: Object): void
		{
			var stepCosts: Array = new Array();
			var stepGrades: Array = new Array();
			var values: Array = new Array();
			var combines: Array = new Array();
			combines[0] = 0;
			values[0] = 1;
			stepGrades[0] = 1;
			var newGrade: Number = stepGrades[0];
			for each(var instr: Object in recipe.Instructions)
			{
				newGrade = (stepGrades[instr.left] == stepGrades[instr.right])?(stepGrades[instr.left] + 1):Math.max(stepGrades[instr.left], stepGrades[instr.right]);
				stepGrades.push(newGrade);
				values.push(values[instr.left] + values[instr.right]);
				combines.push(combines[instr.left] + combines[instr.right] + 1);
			}
			recipe.GradeIncrease = stepGrades.pop() - stepGrades[0];
			recipe.Value = values.pop();
			recipe.Combines = combines.pop();
		}
		
		public function CurrentRecipeName(): String
		{
			if (this.currentRecipeIndex != -1)
			{
				var displayedRecipeName:String = this.recipes[this.currentRecipeIndex].Name;
				displayedRecipeName = displayedRecipeName.substring(0, displayedRecipeName.length-4);
				return displayedRecipeName;
			}
			else
				return "No recipe!";
		}
		
		public function CurrentRecipe(): Object
		{
			if (this.currentRecipeIndex != -1)
				return this.recipes[this.currentRecipeIndex];
			else
				return {Name: "No recipe", Instructions: [], GradeIncrease: NaN, Value: NaN};
		}
		
		public function TotalCombineCostCurrent(sourceGem:Object/*Gem*/): Number
		{
			if (this.currentRecipeIndex != -1)
			{
				var currRecipe: Object = CurrentRecipe();
				return sourceGem.cost.g() * (currRecipe.Value - 1) + this.core.gemCombiningManaCost.g() * currRecipe.Combines;
			}
			else
				return NaN;
		}
		
		// Parses a recipe from a file with the given name
		// Returns a recipe Object that has an array of instuctions, cost multipliers, and a name
		private function LoadRecipeFromFile(recipeFileName: String): Object
		{
			var file:File = File.applicationStorageDirectory.resolvePath("Gemsmith/recipes/" + recipeFileName);
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
				SB.playSound("sndalert");
				GV.vfxEngine.createFloatingText4(GV.main.mouseX,GV.main.mouseY < 60?Number(GV.main.mouseY + 30):Number(GV.main.mouseY - 20),"Error opening the file!",16768392,12,"center",Math.random() * 3 - 1.5,-4 - Math.random() * 3,0,0.55,12,0,1000);
				UglyLog("LoadRecipeFromFile", error.message);
				UglyLog("LoadRecipeFromFile", "In file: " + recipeFileName);
				return new Array();
			}
			var rex:RegExp = /[ \t]+/gim;
			fileContents = fileContents.replace(rex, '');
			var recipe:Object = new Object();
			recipe.Name = recipeFileName;
			recipe.Instructions = new Array();
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
				recipe.Instructions.push({left:gl, right:gr});
			}
			SetCosts(recipe);
			return recipe;
		}

		// CB=Callback
		// This method is called by IngameInputHandler2
		// It either:
		// 1 - Processes the hotkey if it's bound to a Gemsmith function
		// 2 - Substitutes the KeyCode from Gemsmith_config.json
		// Then it either lets the base game handler to run (so it then fires the function with the substituted KeyCode)
		// or stops the base game's handler
		public function CB_InterceptKeyboardEvent(pE: KeyboardEvent) : Boolean
		{
			var continueCallerExecution:Boolean = true;

			if(pE.keyCode == this.configuration["Hotkeys"]["Gemsmith: Cycle selected recipe left"])
			{
				CycleSelectedRecipe(-1);
				continueCallerExecution = false;
			}
			else if(pE.keyCode == this.configuration["Hotkeys"]["Gemsmith: Cycle selected recipe right"])
			{
				CycleSelectedRecipe(1);
				continueCallerExecution = false;
			}
			else if(pE.keyCode == this.configuration["Hotkeys"]["Gemsmith: Perform combine"])
			{
				if (pE.controlKey && pE.altKey && pE.shiftKey)
				{
					SB.playSound("sndalert");
					GV.vfxEngine.createFloatingText4(GV.main.mouseX,GV.main.mouseY < 60?Number(GV.main.mouseY + 30):Number(GV.main.mouseY - 20),"Reloading mods!",16768392,14,"center",Math.random() * 3 - 1.5,-4 - Math.random() * 3,0,0.55,12,0,1000);
					this.core.inputHandler2.reloadMods();
					continueCallerExecution = false;
				}
				else if (pE.altKey)
					ReloadEverything();
				else
					CastCombineOnMouse();
				continueCallerExecution = false;
			}
			else
			{
				for(var name:String in this.defaultHotkeys)
				{
					if(this.defaultHotkeys[name] == pE.keyCode)
					{
						pE.keyCode = this.configuration["Hotkeys"][name];
						continueCallerExecution = true;
						break;
					}
				}
			}

			return continueCallerExecution;   
		}

		// CB=Callback
		// This function is called by IngameInfoPanelRenderer2 after it's done creating a gem's info panel
		// but before it's displayed on the screen
		// Gemsmith adds its own tooltips in this method
		public function CB_GemInfoPanelFormed(vIp:Object/*McInfoPanel*/, gem:Object/*Gem*/, numberFormatter:Object/*NumberFormatter*/): void
		{
			vIp.addExtraHeight(4);
			vIp.addSeparator(0);
			vIp.addTextfield(15015015,"Gemsmith",true,13);
			vIp.addTextfield(16777215,"Recipe name: " + this.CurrentRecipeName(),false,12);
			vIp.addTextfield(this.TotalCombineCostCurrent(gem) <= this.core.getMana()?Number(9756413):Number(13417386),"Combine cost: " + numberFormatter.format(this.TotalCombineCostCurrent(gem)),true,10);
			vIp.addTextfield(14212095,"Recipe value: " + numberFormatter.format(this.CurrentRecipe().Value),true,10);
			vIp.addTextfield(16777215,"Grade increase: +" + this.CurrentRecipe().GradeIncrease,true,10);
		}
		
		private function PrepareFoldersAndLog(): void
		{
			var storageFolder:File = File.applicationStorageDirectory.resolvePath("Gemsmith");
			if(!storageFolder.isDirectory)
				storageFolder.createDirectory();

			logFile = File.applicationStorageDirectory.resolvePath("Gemsmith/Gemsmith_log.log");
			if(logFile.exists)
				logFile.deleteFile();
			logStream = new FileStream();

			var recipesFolder:File = File.applicationStorageDirectory.resolvePath("Gemsmith/recipes");
			if(!recipesFolder.isDirectory)
			{
				UglyLog("PrepareFolders", "Creating ./recipes");
				recipesFolder.createDirectory();
				var exampleRecipeFile:File = File.applicationStorageDirectory.resolvePath("Gemsmith/recipes/example_8combine.txt");
				var eRFStream:FileStream = new FileStream();
				eRFStream.open(exampleRecipeFile, FileMode.WRITE);
				eRFStream.writeUTFBytes("o\r\n0+0\r\n1+0\r\n2+0\r\n3+0\r\n4+0\r\n5+1");
				eRFStream.close();
			}

			var fwgc:File = File.applicationStorageDirectory.resolvePath("FWGC");
			if(!fwgc.isDirectory)
				return;

			UglyLog("PrepareFolders", "Moving stuff from ./FWGC");
			var oldRecipesFolder:File = File.applicationStorageDirectory.resolvePath("FWGC/recipes");
			oldRecipesFolder.copyTo(recipesFolder, true);
			UglyLog("PrepareFolders", "Moved recipes");
			var oldConfig:File = File.applicationStorageDirectory.resolvePath("FWGC/FWGC_config.json");
			if(oldConfig.exists)
			{
				var oldCStream:FileStream = new FileStream()
				oldCStream.open(oldConfig, FileMode.READ);
				var oldJSON:String = oldCStream.readUTFBytes(oldCStream.bytesAvailable);
				oldCStream.close();
				var pattern:RegExp = /FWGC/g;
				oldJSON = oldJSON.replace(pattern,"Gemsmith");
				
				oldCStream.open(oldConfig, FileMode.WRITE);
				oldCStream.writeUTFBytes(oldJSON);
				oldCStream.close();
				oldConfig.copyTo(storageFolder.resolvePath("Gemsmith_config.json"), true);
				UglyLog("PrepareFolders", "Moved config");
			}

			fwgc.moveToTrash();
			UglyLog("PrepareFolders", "Moved ./FWGC to trash!");
		}
		
		public function ReloadEverything(): void
		{
			this.configuration = LoadConfigurationOrDefault();
			this.recipes = FormRecipeList();
			GV.vfxEngine.createFloatingText4(GV.main.mouseX,GV.main.mouseY < 60?Number(GV.main.mouseY + 30):Number(GV.main.mouseY - 20),"Reloaded recipes & config!",99999999,20,"center",0,0,0,0,24,0,1000);
			SB.playSound("sndalert");
		}
	}
}