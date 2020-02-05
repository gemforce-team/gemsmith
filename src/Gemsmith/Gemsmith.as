package Gemsmith
{
	/**
	 * ...
	 * @author Hellrage
	 */
	
	import flash.display.MovieClip;
	import flash.events.Event;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.events.KeyboardEvent;
	import flash.filters.GlowFilter;
	import flash.net.*;
	import Gemsmith.Recipe;
	import Gemsmith.Logger;
	import Gemsmith.InfoPanelState;

	// We extend MovieClip so that flash.display.Loader accepts our class
	// The loader also requires a parameterless constructor (AFAIK), so we also have a .Bind method to bind our class to the game
	public class Gemsmith extends MovieClip
	{
		public static const MOD_VERSION:String = "v1.0 for GCCS 1.0.6";
		//Game objects
		private var core:Object;/*IngameCore*/
		private var cnt:Object;/*CntIngame*/
		public var GV:Object;/*GV*/
		public var SB:Object;/*SB*/
		public var prefs:Object;/*Prefs*/

		private var recipes:Array;
		private var currentRecipeIndex:int;
		private var configuration:Object;
		private var defaultHotkeys:Object;
		private var infoPanelState:int;
		private var updateAvailable:Boolean;
		
		// Parameterless constructor for flash.display.Loader
		public function Gemsmith()
		{
			super();
			prepareFoldersAndLogger();
			Logger.init();
			this.recipes = formRecipeList();
			this.configuration = loadConfigurationOrDefault();
			this.configuration = updateConfig(this.configuration);
			this.defaultHotkeys = createDefaultConfiguration().Hotkeys;
			
			Logger.uglyLog("Gemsmith", "Gemsmith initialized!");
		}
		
		// This method binds the class to the game's objects
		public function bind(gameObjects:Object) : Gemsmith
		{
			//pCore:Object/*IngameCore*/, pCnt:Object/*CntIngame*/, gv:Object/*GV*/, sb:Object/*SB*/
			this.core = gameObjects.core;
			this.cnt = gameObjects.cnt;
			this.SB = gameObjects.SB;
			this.GV = gameObjects.GV;
			this.prefs = gameObjects.prefs;
			this.infoPanelState = InfoPanelState.GEMSMITH;
			this.updateAvailable = false;
			//checkForUpdates();
			Logger.uglyLog("Gemsmith", "Gemsmith bound to game's objects!");
			return this;
		}
		
		// Populates the recipe array with recipes from the respective folder
		private function formRecipeList(): Array
		{
			var newRecipes: Array = new Array();
			var recipesFolder:File = File.applicationStorageDirectory.resolvePath("Gemsmith/recipes");
			
			var fileList: Array = recipesFolder.getDirectoryListing();
			for(var f:int = 0; f < fileList.length; f++)
			{
				var fileName:String = fileList[f].name;
				if (fileName.substring(fileName.length - 4, fileName.length) == ".txt")
				{
					var recipe:Recipe = Recipe.fromFile(fileName);
					if(recipe != Recipe.emptyRecipe)
						newRecipes.push(recipe);
					else
					{
						SB.playSound("sndalert");
						GV.vfxEngine.createFloatingText(GV.main.mouseX,GV.main.mouseY < 60?Number(GV.main.mouseY + 30):Number(GV.main.mouseY - 20),"Error opening" + fileName + "!",16768392,12,"center",Math.random() * 3 - 1.5,-4 - Math.random() * 3,0,0.55,12,0,1000);
					}
				}
			}
			Logger.uglyLog("FormRecipeList", "Found " + newRecipes.length + " recipe files.");
			if (newRecipes.length == 0)
			{
				this.currentRecipeIndex = -1;
			}
			else
			{
				this.currentRecipeIndex = 0;
			}
			newRecipes.sortOn("name");
			return newRecipes;
		}

		private function loadConfigurationOrDefault(): Object
		{
			var configFile:File = File.applicationStorageDirectory.resolvePath("Gemsmith/Gemsmith_config.json");
			var configStream:FileStream = new FileStream();
			var config:Object = null;
			var configJSON:String = null;

			if(!configFile.exists)
			{
				config = createDefaultConfiguration();
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
					
					Logger.uglyLog("LoadConfiguration", "Loaded existing configuration");
				}
				catch(error:Error)
				{
					config = createDefaultConfiguration();
					Logger.uglyLog("LoadConfiguration", "There was an error when loading an existing config file:");
					Logger.uglyLog("LoadConfiguration", error.message);
					Logger.uglyLog("LoadConfiguration", "Configuration was reset to defaults");
				}
				configStream.close();

				if(config == null || config["Hotkeys"] == null)
				{
					config = createDefaultConfiguration();
					Logger.uglyLog("LoadConfiguration", "Configuration was invalid for some reason, using defaults");
				}
			}
			return config;
		}

		private function createDefaultConfiguration(): Object
		{
			var config:Object = new Object();
			config["Hotkeys"] = new Object();
			config["Hotkeys"]["Throw gem bombs"] = 66;
			config["Hotkeys"]["Build tower"] = 84;
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
			config["Hotkeys"]["Cast curse strike spell"] = 50;
			config["Hotkeys"]["Cast wake of eternity strike spell"] = 51;
			config["Hotkeys"]["Cast bolt enhancement spell"] = 52;
			config["Hotkeys"]["Cast beam enhancement spell"] = 53;
			config["Hotkeys"]["Cast barrage enhancement spell"] = 54;
			config["Hotkeys"]["Create Mana Leeching gem"] = 103;
			config["Hotkeys"]["Create Critical Hit gem"] = 104;
			config["Hotkeys"]["Create Poolbound gem"] = 105;
			config["Hotkeys"]["Create Chain Hit gem"] = 100;
			config["Hotkeys"]["Create Poison gem"] = 101;
			config["Hotkeys"]["Create Suppression gem"] = 102;
			config["Hotkeys"]["Create Bloodbound gem"] = 97;
			config["Hotkeys"]["Create Slowing gem"] = 98;
			config["Hotkeys"]["Create Armor Tearing gem"] = 99;
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
		private function updateConfig(config:Object) : Object
		{
			var oldConfigFile:File = File.applicationStorageDirectory.resolvePath("Gemsmith/Gemsmith_config.json.backup");
			var configStream:FileStream = new FileStream();
			configStream.open(oldConfigFile, FileMode.WRITE);
			configStream.writeUTFBytes(JSON.stringify(this.configuration, null, 2));
			configStream.close();
			for(var name:String in this.defaultHotkeys)
			{
				if(!config["Hotkeys"][name])
					config["Hotkeys"][name] = this.defaultHotkeys[name];
			}
			if (config["Check for updates"] == null)
				config["Check for updates"] = true;
				
			var configFile:File = File.applicationStorageDirectory.resolvePath("Gemsmith/Gemsmith_config.json");
			configStream.open(configFile, FileMode.WRITE);
			configStream.writeUTFBytes(JSON.stringify(this.configuration, null, 2));
			configStream.close();
			return config;
		}

		public function cycleSelectedRecipe(increment:int): void
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
		public function castCombineOnMouse(): void
		{
			if(this.currentRecipeIndex == -1)
			{
				SB.playSound("sndalert");
				GV.vfxEngine.createFloatingText(GV.main.mouseX,GV.main.mouseY < 60?Number(GV.main.mouseY + 30):Number(GV.main.mouseY - 20),"No recipe selected!",16768392,14,"center",Math.random() * 3 - 1.5,-4 - Math.random() * 3,0,0.55,12,0,1000);
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
						var recipe: Recipe = this.recipes[this.currentRecipeIndex];
						var combineCost: Number = totalCombineCost(recipe, gem);
						if(this.core.getMana() >= combineCost)
						{
							var resultingGem:Object/*Gem*/ = null;
							var invSlot:int = this.core.inventorySlots.indexOf(gem);
							resultingGem = virtualCombineGem(recipe, gem);
							if(invSlot != -1)
							{
								this.core.inventorySlots[invSlot] = null;
								this.core.controller.placeGemIntoSlot(resultingGem, invSlot);
							}
							/*else if(this.core.gemInEnragingSlot == gem)
							{
								this.core.cnt.cntGemInEnragingSlot.removeChild(gem.mc);

								this.core.gemInEnragingSlot = null;
								this.core.inputHandler.insertGemToEnragingSlot(resultingGem);
								GV.ingameAchiCtrl.checkAchi(117,true,true);
							}*/
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

									this.core.spellCaster.cnt.cntGemsInInventory.removeChild(selectedBuilding.insertedGem.mc);
									this.core.spellCaster.cnt.cntGemsInTowers.removeChild(selectedBuilding.insertedGem.mc);
									this.core.spellCaster.cnt.cntDraggedGem.removeChild(selectedBuilding.insertedGem.mc);
									
									selectedBuilding.removeGem();
									selectedBuilding.insertGem(resultingGem);
								}
								else
								{
									SB.playSound("sndalert");
									GV.vfxEngine.createFloatingText(GV.main.mouseX,GV.main.mouseY < 60?Number(GV.main.mouseY + 30):Number(GV.main.mouseY - 20),"Can't find where the gem is!",16768392,20,"center",Math.random() * 3 - 1.5,-4 - Math.random() * 3,0,0.55,12,0,1000);
									return;
								}                          
							}
							// Check that there wasn't an exception
							if (gem != resultingGem)
							{
								if(this.core.gems.indexOf(gem) >= 0)
									this.core.gems.splice(this.core.gems.indexOf(gem), 1);
								this.core.gems.push(resultingGem);
								
								this.core.changeMana( -combineCost, false, true);
							}
							this.core.controller.deselectEverything(true,true);
							SB.playSound("sndgemcombined");
						}
						else
						{
							SB.playSound("sndalert");
							GV.vfxEngine.createFloatingText(GV.main.mouseX,GV.main.mouseY < 60?Number(GV.main.mouseY + 30):Number(GV.main.mouseY - 20),"Not enough mana",16768392,12,"center",Math.random() * 3 - 1.5,-4 - Math.random() * 3,0,0.55,12,0,1000);
							return;
						}
					}
					else
					{
						SB.playSound("sndalert");
						GV.vfxEngine.createFloatingText(GV.main.mouseX,GV.main.mouseY < 60?Number(GV.main.mouseY + 30):Number(GV.main.mouseY - 20),"No gem under cursor",16768392,12,"center",Math.random() * 3 - 1.5,-4 - Math.random() * 3,0,0.55,12,0,1000);
						return;
					}
				}
			}
			catch(error:Error)
			{
				// TODO handle this exception wrt the gem
				Logger.uglyLog("CastCombineOnMouse", "Caught an exception!");
				Logger.uglyLog("CastCombineOnMouse", error.message);
				SB.playSound("sndalert");
				GV.vfxEngine.createFloatingText(GV.main.mouseX,GV.main.mouseY < 60?Number(GV.main.mouseY + 30):Number(GV.main.mouseY - 20),"Caught an exception!",16768392,20,"center",Math.random() * 3 - 1.5,-4 - Math.random() * 3,0,0.55,12,0,1000);
				return;
			}
		}

		// Worker method, this bypasses the game's tracking of mana expenditure
		// Takes a recipe and performs the combine without using any inventory slots
		private function performCombineFromRecipe(recipe: Recipe, sourceGem:Object/*Gem*/): Object
		{
			var resultingGem:Object = null;
			var localinstructions: Array = recipe.instructions;
			
			if(sourceGem == null)
				return sourceGem;
			
			var virtualInv: Array = new Array();
			virtualInv[0] = sourceGem;
			
			try 
			{
				// We're handling mana expenditure stats ourselves
				var sourceCombiningCost: Number = sourceGem.combinationManaValue.g();
				var sourceComponentCosts: Array = new Array(0, 0, 0, 0, 0, 0, 0, 0, 0);
				for(var c: int = 0; c < 9; c++)
					sourceComponentCosts[c] = sourceGem.manaValuesByComponent[c].g();

				// Arrays to hold the step-by-step costs, these are filled as we perform the combine
				var stepCombiningCost: Array = new Array();
				var stepComponentCosts: Array = new Array();
				stepCombiningCost.push(sourceCombiningCost);
				stepComponentCosts.push(sourceComponentCosts.concat());

				for each(var instr: Object in localinstructions)
				{
					var res:Object = this.core.spellCaster.combineGems(virtualInv[instr.left], virtualInv[instr.right], true, true, false);
					res.kills.s(Math.round(res.kills.g() / 2));
					res.hits.s(Math.round(res.hits.g() / 2));
					//res.manaLeeched = res.manaLeeched / 2;
					virtualInv.push(res);

					// Now we fill in the mana expenditure values
					stepCombiningCost.push(stepCombiningCost[instr.left] + stepCombiningCost[instr.right] + this.core.gemCombiningManaCost.g());
					stepComponentCosts.push(addByComponentCosts(stepComponentCosts[instr.left], stepComponentCosts[instr.right]));
				}

				resultingGem = virtualInv.pop();
				var totalCombiningCost: Number = stepCombiningCost.pop();
				
				// We're handling stats ourselves
				resultingGem.combinationManaValue.s(totalCombiningCost);

				this.core.spellCaster.stats.spentManaOnCombinationCost += totalCombiningCost - sourceCombiningCost;

				var resultingComponentCosts: Array = stepComponentCosts.pop();
				//this.core.spellCaster.stats.spentManaOnBleedingGem += resultingComponentCosts[2] - sourceComponentCosts[2];
				this.core.spellCaster.stats.spentManaOnCritHitGem += resultingComponentCosts[1] - sourceComponentCosts[1];
				this.core.spellCaster.stats.spentManaOnPoisonGem += resultingComponentCosts[4] - sourceComponentCosts[4];
				this.core.spellCaster.stats.spentManaOnSlowingGem += resultingComponentCosts[7] - sourceComponentCosts[7];
				this.core.spellCaster.stats.spentManaOnManaLeechingGem += resultingComponentCosts[0] - sourceComponentCosts[0];
				this.core.spellCaster.stats.spentManaOnArmorTearingGem += resultingComponentCosts[8] - sourceComponentCosts[8];
				this.core.spellCaster.stats.spentManaOnPoolboundGem += resultingComponentCosts[2] - sourceComponentCosts[2];
				this.core.spellCaster.stats.spentManaOnBloodboundGem += resultingComponentCosts[6] - sourceComponentCosts[6];
				this.core.spellCaster.stats.spentManaOnSuppressingGem += resultingComponentCosts[5] - sourceComponentCosts[5];
				this.core.spellCaster.stats.spentManaOnChainHitGem += resultingComponentCosts[3] - sourceComponentCosts[3];
				
				this.core.spellCaster.stats.highestGradeGemCreated = Math.max(resultingGem.grade.g() + 1, this.core.spellCaster.stats.highestGradeGemCreated);
				this.core.stats.gemHighestMaxDamage = Math.max(this.core.stats.gemHighestMaxDamage, resultingGem.sd2_CompNumMod.damageMax.g());
			 
				return resultingGem;
			}
			catch(error: Error) {
				SB.playSound("sndalert");
				GV.vfxEngine.createFloatingText(GV.main.mouseX, (GV.main.mouseY < 60) ? Number(GV.main.mouseY + 30) : Number(GV.main.mouseY - 20), "An error occured!", 16768392, 12, "center", Math.random() * 3 - 1.5, -4 - Math.random() * 3, 0, 0.55, 12, 0, 1000);
				Logger.uglyLog("PerformCombineFrominstructions", "Caught an exception!");
				Logger.uglyLog("PerformCombineFrominstructions", error.message);
				return sourceGem;
			}
			return sourceGem;
		}

		// This is the main method, takes a gem, carefully performs the combine, returns the new gem
		// Also handles gem bitmap creation
		private function virtualCombineGem(recipe: Recipe, gem:Object/*Gem*/): Object
		{
			// Remember the modified range
			var vRangeRatio:Number = NaN;
			var vRange4:Number = NaN;
			var vRange5:Number = NaN;
			vRangeRatio = gem.rangeRatio.g();
			vRange4 = gem.sd4_BoundMod.range.g();
			vRange5 = gem.sd5_EnhancedOrTrap.range.g();
			gem.rangeRatio.s(1);
			gem.sd4_BoundMod.range.s(vRange4 / vRangeRatio * gem.rangeRatio.g());
			gem.sd5_EnhancedOrTrap.range.s(vRange5 / vRangeRatio * gem.rangeRatio.g());

			// In case of failure we just return the source gem
			var resultingGem:Object = performCombineFromRecipe(recipe, gem) || gem;
			resultingGem.recalculateSds();
			GV.gemBitmapCreator.giveGemBitmaps(resultingGem);

			// Restore the modified range
			vRange4 = resultingGem.sd4_BoundMod.range.g();
			vRange5 = resultingGem.sd5_EnhancedOrTrap.range.g();
			resultingGem.rangeRatio.s(vRangeRatio);
			resultingGem.sd4_BoundMod.range.s(vRange4 * resultingGem.rangeRatio.g());
			resultingGem.sd5_EnhancedOrTrap.range.s(vRange5 * resultingGem.rangeRatio.g());

			return resultingGem;
		}
		
		// A helper method for summing two gems' component costs
		private function addByComponentCosts(cc1: Array, cc2: Array): Array
		{
			var cc3: Array = new Array(0, 0, 0, 0, 0, 0, 0, 0, 0);/*Gem component costs*/
			for(var c: int = 0; c < 9; c++)
				cc3[c] = cc1[c]+cc2[c];
			return cc3;
		}

		public function totalCombineCost(recipe: Recipe, sourceGem:Object/*Gem*/): Number
		{
			return sourceGem.cost.g() * (recipe.value - 1) + this.core.gemCombiningManaCost.g() * recipe.combines;
		}

		public function currentRecipeName(): String
		{
			if (this.currentRecipeIndex != -1)
			{
				return this.recipes[this.currentRecipeIndex].name;
			}
			else
				return "No recipe!";
		}
		
		public function currentRecipe(): Recipe
		{
			if (this.currentRecipeIndex != -1)
				return this.recipes[this.currentRecipeIndex];
			else
				return Recipe.emptyRecipe;
		}
		
		public function totalCombineCostCurrent(sourceGem:Object/*Gem*/): Number
		{
			if (this.currentRecipeIndex != -1)
			{
				var currRecipe: Object = currentRecipe();
				return sourceGem.cost.g() * (currRecipe.value - 1) + this.core.gemCombiningManaCost.g() * currRecipe.combines;
			}
			else
				return NaN;
		}

		// CB=Callback
		// This method is called by IngameInputHandler2
		// It either:
		// 1 - Processes the hotkey if it's bound to a Gemsmith function
		// 2 - Substitutes the KeyCode from Gemsmith_config.json
		// Then it either lets the base game handler to run (so it then fires the function with the substituted KeyCode)
		// or stops the base game's handler
		public function cb_interceptKeyboardEvent(pE: KeyboardEvent) : Boolean
		{
			var continueCallerExecution:Boolean = true;

			if(pE.keyCode == this.configuration["Hotkeys"]["Gemsmith: Cycle selected recipe left"])
			{
				cycleSelectedRecipe(-1);
				continueCallerExecution = false;
			}
			else if(pE.keyCode == this.configuration["Hotkeys"]["Gemsmith: Cycle selected recipe right"])
			{
				cycleSelectedRecipe(1);
				continueCallerExecution = false;
			}
			else if(pE.keyCode == this.configuration["Hotkeys"]["Gemsmith: Perform combine"])
			{
				if (pE.controlKey && pE.altKey && pE.shiftKey)
				{
					SB.playSound("sndalert");
					GV.vfxEngine.createFloatingText(GV.main.mouseX,GV.main.mouseY < 60?Number(GV.main.mouseY + 30):Number(GV.main.mouseY - 20),"Reloading mods!",16768392,14,"center",Math.random() * 3 - 1.5,-4 - Math.random() * 3,0,0.55,12,0,1000);
					this.core.inputHandler2.reloadMods();
					continueCallerExecution = false;
				}
				else if (pE.altKey)
					reloadEverything();
				else
					castCombineOnMouse();
				continueCallerExecution = false;
			}
			else if(pE.keyCode == this.configuration["Hotkeys"]["Show/hide info panels"])
			{
				if (this.infoPanelState == InfoPanelState.HIDDEN)
				{
					this.infoPanelState = InfoPanelState.BASEGAME;
					continueCallerExecution = true;
				}
				else if (this.infoPanelState == InfoPanelState.BASEGAME)
				{
					this.infoPanelState = InfoPanelState.GEMSMITH;
					continueCallerExecution = false;
				}
				else
				{
					this.infoPanelState = InfoPanelState.HIDDEN;
					continueCallerExecution = true;
				}
			}
			else
			{
				for(var name:String in this.defaultHotkeys)
				{
					if(this.defaultHotkeys[name] == pE.keyCode)
					{
						pE.keyCode = this.configuration["Hotkeys"][name] || 0;
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
		public function cb_gemInfoPanelFormed(vIp:Object/*McInfoPanel*/, gem:Object/*Gem*/, numberFormatter:Object/*NumberFormatter*/): void
		{
			if (this.infoPanelState == InfoPanelState.GEMSMITH)
			{
				vIp.addExtraHeight(4);
				vIp.addSeparator(0);
				vIp.addTextfield(15015015,"Gemsmith",true,13, [new GlowFilter(0,1,3,6),new GlowFilter(16056320,0.28,25,12)]);
				vIp.addTextfield(16777215,"Recipe name: " + this.currentRecipeName(),false,12);
				vIp.addTextfield(this.totalCombineCostCurrent(gem) <= this.core.getMana()?Number(9756413):Number(13417386),"Combine cost: " + numberFormatter.format(this.totalCombineCostCurrent(gem)),true,10);
				vIp.addTextfield(14212095,"Recipe value: " + numberFormatter.format(this.currentRecipe().value),true,10);
				vIp.addTextfield(16777215, "Grade increase: +" + this.currentRecipe().gradeIncrease, false, 10);
				if(this.updateAvailable)
					vIp.addTextfield(4748628, "Update available!", true, 7);
				else
					vIp.addTextfield(10526880, "Mod version: " + MOD_VERSION, true, 7);
			}
		}
		
		private function prepareFoldersAndLogger(): void
		{
			var storageFolder:File = File.applicationStorageDirectory.resolvePath("Gemsmith");
			if(!storageFolder.isDirectory)
				storageFolder.createDirectory();

			Logger.init();
				
			var recipesFolder:File = File.applicationStorageDirectory.resolvePath("Gemsmith/recipes");
			if(!recipesFolder.isDirectory)
			{
				Logger.uglyLog("PrepareFolders", "Creating ./recipes");
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

			Logger.uglyLog("PrepareFolders", "Moving stuff from ./FWGC");
			var oldRecipesFolder:File = File.applicationStorageDirectory.resolvePath("FWGC/recipes");
			oldRecipesFolder.copyTo(recipesFolder, true);
			Logger.uglyLog("PrepareFolders", "Moved recipes");
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
				Logger.uglyLog("PrepareFolders", "Moved config");
			}

			fwgc.moveToTrash();
			Logger.uglyLog("PrepareFolders", "Moved ./FWGC to trash!");
		}
		
		public function reloadEverything(): void
		{
			this.configuration = loadConfigurationOrDefault();
			this.recipes = formRecipeList();
			GV.vfxEngine.createFloatingText(GV.main.mouseX,GV.main.mouseY < 60?Number(GV.main.mouseY + 30):Number(GV.main.mouseY - 20),"Reloaded recipes & config!",99999999,20,"center",0,0,0,0,24,0,1000);
			SB.playSound("sndalert");
		}
		
		private function checkForUpdates(): void
		{
			if(!this.configuration["Check for updates"])
				return;
			
			Logger.uglyLog("CheckForUpdates", "Mod version: " + MOD_VERSION);
			Logger.uglyLog("CheckForUpdates", "Checking for updates...");
			var repoAddress:String = "https://api.github.com/repos/gemforce-team/gemsmith/releases/latest";
			var request:URLRequest = new URLRequest(repoAddress);

			var loader:URLLoader = new URLLoader();
			var localThis:Gemsmith = this;
			try
			{
				loader.load(request);
				loader.addEventListener(Event.COMPLETE, function(e:Event): void{
					var latestTag:String = JSON.parse(loader.data).tag_name.replace(/[-]/gim,' ');
					localThis.updateAvailable = (latestTag != MOD_VERSION);
					Logger.uglyLog("CheckForUpdates", localThis.updateAvailable ? "Update available! " + latestTag : "Using the latest version:" + latestTag);
				});
			}
			catch(err:Error)
			{
				Logger.uglyLog("CheckForUpdates", "Caught an error when checking for updates!");
				Logger.uglyLog("CheckForUpdates", err.message);
			}
		}
	}
}