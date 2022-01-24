package Gemsmith
{
	/**
	 * ...
	 * @author Hellrage
	 */
	
	import Bezel.Events.EventTypes;
	import Bezel.Events.IngameGemInfoPanelFormedEvent;
	import Bezel.Events.IngameKeyDownEvent;
	import Bezel.Utils.Keybind;
	import Bezel.Utils.SettingManager;
	
	import com.giab.games.gcfw.GV;
	import com.giab.games.gcfw.SB;
	import com.giab.games.gcfw.constants.ActionStatus;
	import com.giab.games.gcfw.constants.GemComponentType;
	import com.giab.games.gcfw.entity.Gem;
	import com.giab.games.gcfw.entity.Trap;
	import com.giab.games.gcfw.ingame.IngameCore;
	import com.giab.games.gcfw.mcDyn.McInfoPanel;
	import com.giab.games.gcfw.mcStat.CntIngame;
	
	import flash.display.MovieClip;
	import flash.events.*;
	import flash.filesystem.*;
	import flash.filters.GlowFilter;
	import flash.net.*;
	import flash.system.*;

	// We extend MovieClip so that flash.display.Loader accepts our class
	// The loader also requires a parameterless constructor (AFAIK), so we also have a .Bind method to bind our class to the game
	public class GCFWGemsmith extends MovieClip
	{	
		// Game object shortcuts
		internal var core:IngameCore;/*IngameCore*/
		internal var cnt:CntIngame;/*CntIngame*/
		
		internal static var storage:File;

		private var recipes:Array;
		private var currentRecipeIndex:int;
		private var infoPanelState:int;
		private var updateAvailable:Boolean;
		private var ctrlKeyHeld: Boolean;
		private static var settings:SettingManager;
		
		// Parameterless constructor for flash.display.Loader
		public function GCFWGemsmith()
		{
			super();
			
			storage = File.applicationStorageDirectory;
			this.core = GV.ingameCore;
			this.cnt = GV.main.cntScreens.cntIngame;
			
			prepareFoldersAndLogger();
			this.infoPanelState = InfoPanelState.GEMSMITH;
			this.updateAvailable = false;
			this.ctrlKeyHeld = false;
			
			settings = SettingManager.getManager("Gemsmith");
			settings.registerBoolean("Check for updates", null, true, "Checks for updates when mod is loaded");
			
			registerKeybinds();

			addEventListeners();
			
			if(settings.retrieveBoolean("Check for updates"))
				checkForUpdates();
			
			GemsmithMod.logger.log("Gemsmith", "Gemsmith initialized!");
		}
		
		// Populates the recipe array with recipes from the respective folder
		internal function formRecipeList(...args): void
		{
			var newRecipes: Array = new Array();
			var recipesFolder:File = storage.resolvePath("Gemsmith/recipes");
			
			var fileList: Array = recipesFolder.getDirectoryListing();
			for(var f:int = 0; f < fileList.length; f++)
			{
				var fileName:String = fileList[f].name;
				if (fileName.substring(fileName.length - 4, fileName.length) == ".txt")
				{
					var recipe:Recipe = Recipe.fromFile(recipesFolder.resolvePath(fileName).nativePath);
					if(recipe != Recipe.emptyRecipe)
						newRecipes.push(recipe);
					else
					{
						SB.playSound("sndalert");
						GV.vfxEngine.createFloatingText4(GV.main.mouseX,GV.main.mouseY < 60?Number(GV.main.mouseY + 30):Number(GV.main.mouseY - 20),"Error opening" + fileName + "!",16768392,12,"center",Math.random() * 3 - 1.5,-4 - Math.random() * 3,0,0.55,12,0,1000);
					}
				}
			}
			GemsmithMod.logger.log("FormRecipeList", "Found " + newRecipes.length + " recipe files.");
			if (newRecipes.length == 0)
			{
				this.currentRecipeIndex = -1;
			}
			else
			{
				this.currentRecipeIndex = 0;
			}
			newRecipes.sortOn("name");
			this.recipes = newRecipes;
		}

		public function cycleSelectedRecipe(increment:int): void
		{
			if(this.currentRecipeIndex == -1)
				return;
				
			var gem:Gem = this.core.controller.getGemUnderPointer(false);
			if (!gem)
				return;
			
			this.currentRecipeIndex += increment;
			if(this.currentRecipeIndex < 0)
				this.currentRecipeIndex = recipes.length - 1;
			else if(this.currentRecipeIndex > recipes.length - 1)
				this.currentRecipeIndex = 0;
			this.core.infoPanelRenderer2.renderInfoPanelGem(gem, gem.containingBuilding);
		}

		// Main method, this is called when pressing the hotkey
		// Handles gems in any slot, takes care of inserting it back into buildings
		public function castCombineOnMouse(): void
		{
			if (CONFIG::debug)
			{
				GV.ingameCore.changeMana( - GV.ingameCore.getMana(), false, false);
				GV.ingameCore.changeMana( 100000000000, false, true);
			}
			if(this.currentRecipeIndex == -1)
			{
				displayErrorMessage("No recipe selected!");
				return;
			}
			
			if(GV.ingameCore.actionStatus == ActionStatus.CAST_GEMBOMB_INITIATED)
			{
				GV.ingameCore.controller.deselectEverything(true,false);
			}

			try
			{
				if(GV.ingameCore.actionStatus < ActionStatus.DRAGGING_GEM_FROM_TOWER_IDLE || GV.ingameCore.actionStatus >= ActionStatus.CAST_ENHANCEMENT_INITIATED)
				{
					var gem:Gem = GV.ingameCore.controller.getGemUnderPointer(false);
					var recipe: Recipe = this.currentRecipe();
					
					if((gem == null) && (recipe.type == "Combine"))
					{
						displayErrorMessage("No gem under cursor");
						return;
					}
					
					// First check if we have enough mana for it 
					var combineCost: Number = totalCombineCost(recipe, gem);
					if(GV.ingameCore.getMana() < combineCost)
					{
						displayErrorMessage("Not enough mana");
						return;
					}
					
					var selectedBuilding:Object = findSlottableBuildingUnderCursor();
					if (selectedBuilding is Trap && selectedBuilding.insertedGem != null)
						selectedBuilding.mc.cnt.removeChild(selectedBuilding.insertedGem.mc);
						
					var resultingGem:Gem = null;
					var invSlot:int;
					var depositGem:Function;
					
					if (recipe.type == "Combine")
					{
						invSlot = GV.ingameCore.inventorySlots.indexOf(gem);
						if (invSlot != - 1)
						{
							depositGem = insertGemIntoInventoryAction(invSlot);
						}
						else if(enrageSlotSelected())
						{
							depositGem = insertGemIntoEnrageSlotAction(true);
						}
						else if (selectedBuilding != null)
						{
							depositGem = insertGemIntoBuildingAction(selectedBuilding, true);
						}
					}
					else if (recipe.type == "Spec")
					{
						for each(var type:int in recipe.seedGems)
							if (!GV.ingameCore.arrIsSpellBtnVisible[type])
							{
								displayErrorMessage("Gem color unavailable!");
								return;
							}
							
						
						invSlot = GV.ingameCore.calculator.findFirstEmptyInvSlot();
						if (selectedBuilding != null && selectedBuilding.insertedGem == null)
						{
							depositGem = insertGemIntoBuildingAction(selectedBuilding, false);
						}
						else if (enrageSlotSelected() && GV.ingameCore.gemInEnragingSlot == null)
						{
							depositGem = insertGemIntoEnrageSlotAction(false);
						}
						else if(invSlot != -1)
						{
							depositGem = insertGemIntoInventoryAction(invSlot);
						}
						else 
						{
							displayErrorMessage("No place for the gem!");
							return;
						}
					}
					
					resultingGem = virtualCombineGem(recipe, gem);
					
					if (resultingGem == null)
					{
						displayErrorMessage("Can't make the gem!");
						return;
					}
					
					depositGem(resultingGem);
					
					if(GV.ingameCore.gems.indexOf(gem) >= 0)
						GV.ingameCore.gems.splice(GV.ingameCore.gems.indexOf(gem), 1);
						
					GV.ingameCore.gems.push(resultingGem);
					GV.ingameCore.changeMana( -combineCost, false, true);
					GV.ingameCore.controller.deselectEverything(true, true);
					
					SB.playSound("sndgemcombined");
				}
			}
			catch(error:Error)
			{
				// TODO handle this exception wrt the gem
				GemsmithMod.logger.log("CastCombineOnMouse", "Caught an exception!");
				GemsmithMod.logger.log("CastCombineOnMouse", error.message);
				GemsmithMod.logger.log("CastCombineOnMouse", error.getStackTrace());
				displayErrorMessage("Caught an exception!");
				return;
			}
		}
		
		private function insertGemIntoInventoryAction(invSlot: Number): Function
		{
			return function(gem: Gem): void 
			{
				GV.ingameCore.inventorySlots[invSlot] = null;
				GV.ingameCore.controller.placeGemIntoSlot(gem, invSlot);
			}
		}
		
		private function insertGemIntoBuildingAction(building: Object, removePrevious: Boolean): Function
		{
			return function(gem: Gem): void 
			{
				if (removePrevious)
				{
					GV.ingameCore.spellCaster.cnt.cntGemsInInventory.removeChild(building.insertedGem.mc);
					GV.ingameCore.spellCaster.cnt.cntGemsInTowers.removeChild(building.insertedGem.mc);
					GV.ingameCore.spellCaster.cnt.cntDraggedGem.removeChild(building.insertedGem.mc);
					
					building.removeGem();
				}
				building.insertGem(gem);
			}
		}
		
		private function insertGemIntoEnrageSlotAction(removePrevious: Boolean): Function
		{
			return function(gem: Gem): void 
			{
				if (removePrevious)
				{
					GV.ingameCore.cnt.cntGemInEnragingSlot.removeChild(GV.ingameCore.gemInEnragingSlot.mc);
					GV.ingameCore.gemInEnragingSlot = null;
				}
				GV.ingameCore.inputHandler.insertGemToEnragingSlot(gem);
				GV.ingameAchiCtrl.checkAchi(117,true,true);
			}
		}
		
		private function enrageSlotSelected(): Boolean
		{
			var mX: Number = GV.main.mouseX;
			var mY: Number = GV.main.mouseY;
			return (mX > 4 && mX < 43 && mY > 8 && mY < 47);
		}
		
		public function displayErrorMessage(text: String): void
		{
			SB.playSound("sndalert");
			GV.vfxEngine.createFloatingText4(GV.main.mouseX,GV.main.mouseY < 60?Number(GV.main.mouseY + 30):Number(GV.main.mouseY - 20),text,16768392,12,"center",Math.random() * 3 - 1.5,-4 - Math.random() * 3,0,0.55,12,0,1000);
		}

		public function findSlottableBuildingUnderCursor(): Object
		{
			var vX:Number = Math.floor((GV.main.mouseX - GemsmithMod.WAVESTONE_WIDTH) / GemsmithMod.TILE_SIZE);
			var vY:Number = Math.floor((GV.main.mouseY - GemsmithMod.TOP_UI_HEIGHT) / GemsmithMod.TILE_SIZE);
			
			if (vX >= GemsmithMod.FIELD_WIDTH - 1 || vX < 1 || vY >= GemsmithMod.FIELD_HEIGHT - 1 || vY < 1)
				return null;
			var grid: Object = GV.ingameCore.buildingRegPtMatrix;
			var building:Object = grid[vY][vX] || grid[vY - 1][vX] || grid[vY][vX - 1] || grid[vY - 1][vX - 1];
			if (building != null && building.hasOwnProperty("insertedGem"))
				return building;
			else
				return null;
		}
		
		public function conjureGemOnMouse(): void
		{
			var invSlot:int = this.core.calculator.findFirstEmptyInvSlot();
			if (invSlot != -1)
			{
				var newGem:Gem = conjureGem(this.currentRecipe(), 1, 1);
				newGem.targetPriority = 4;
				this.core.controller.placeGemIntoSlot(newGem, invSlot);
				this.core.gems.push(newGem);
			}
		}
		
		// Worker method, this bypasses the game's tracking of mana expenditure
		// Takes a recipe and performs the combine without using any inventory slots
		private function performCombineFromRecipe(recipe: Recipe, sourceGem:Gem): Gem
		{
			var resultingGem:Gem = null;
			var localinstructions: Array = recipe.instructions;
			
			if(sourceGem == null && recipe.type != "Spec")
				return sourceGem;
				
			if (recipe == Recipe.emptyRecipe)
				return sourceGem;
				
			try 
			{
				var virtualInv: Array = new Array();
				
				// We're handling mana expenditure stats ourselves
				var sourceCombiningCost: Number;
				var sourceComponentCosts: Array;
				
				// Arrays to hold the step-by-step costs, these are filled as we perform the combine
				var stepCombiningCost: Array = new Array();
				var stepComponentCosts: Array = new Array();
				if (recipe.type == "Spec")
				{
					//These are subtracted to calculate mana expenditure, but we're making them ourselves so we shouldn't
					sourceComponentCosts = new Array(0, 0, 0, 0, 0, 0);
					sourceCombiningCost = 0;
					for (var step: String in recipe.seedGems)
					{
						if (!gemTypeAvailable(recipe.seedGems[step]))
							return null;
						var seed: Gem = createPureGem(recipe.seedGems[step]);
						
						virtualInv[step] = seed;
						stepCombiningCost[step] = 0;
						stepComponentCosts[step] = new Array();
						// We're handling mana expenditure stats ourselves
						for(var sc: int = 0; sc < sourceComponentCosts.length; sc++)
							stepComponentCosts[step][sc] = virtualInv[step].manaValuesByComponent[sc].g();
					}
				}
				else
				{
					sourceCombiningCost = sourceGem.combinationManaValue.g();
					sourceComponentCosts = new Array(0, 0, 0, 0, 0, 0);
					for(var c: int = 0; c < sourceComponentCosts.length; c++)
						sourceComponentCosts[c] = sourceGem.manaValuesByComponent[c].g();
					virtualInv[0] = sourceGem;
					stepCombiningCost[0] = sourceCombiningCost;
					stepComponentCosts[0] = sourceComponentCosts.concat();
				}
				
				var instrindex: String;
				for(instrindex in localinstructions)
				{
					var instr: Object = localinstructions[instrindex];
					var res:Gem = GV.ingameCore.spellCaster.combineGems(virtualInv[instr.left], virtualInv[instr.right], true, true, false);
					res.kills.s(Math.round(res.kills.g() / 2));
					res.hits.s(Math.round(res.hits.g() / 2));
					virtualInv[instrindex] = (res);
					
					// Now we fill in the mana expenditure values
					stepCombiningCost[instrindex] = (stepCombiningCost[instr.left] + stepCombiningCost[instr.right] + GV.ingameCore.gemCombiningManaCost.g());
					stepComponentCosts[instrindex] = (addByComponentCosts(stepComponentCosts[instr.left], stepComponentCosts[instr.right]));
				}
				
				resultingGem = virtualInv[instrindex];
				var totalCombiningCost: Number = stepCombiningCost[instrindex];
				
				// We're handling stats ourselves
				resultingGem.combinationManaValue.s(totalCombiningCost);
				
				GV.ingameCore.spellCaster.stats.spentManaOnCombinationCost += totalCombiningCost - sourceCombiningCost;
				
				var resultingComponentCosts: Array = stepComponentCosts[instrindex];
				GV.ingameCore.spellCaster.stats.spentManaOnBleedingGem += resultingComponentCosts[GemComponentType.BLEEDING] - sourceComponentCosts[GemComponentType.BLEEDING];
				GV.ingameCore.spellCaster.stats.spentManaOnCritHitGem += resultingComponentCosts[GemComponentType.CRITHIT] - sourceComponentCosts[GemComponentType.CRITHIT];
				GV.ingameCore.spellCaster.stats.spentManaOnPoisonGem += resultingComponentCosts[GemComponentType.POISON] - sourceComponentCosts[GemComponentType.POISON];
				GV.ingameCore.spellCaster.stats.spentManaOnSlowingGem += resultingComponentCosts[GemComponentType.SLOWING] - sourceComponentCosts[GemComponentType.SLOWING];
				GV.ingameCore.spellCaster.stats.spentManaOnManaLeechingGem += resultingComponentCosts[GemComponentType.MANA_LEECHING] - sourceComponentCosts[GemComponentType.MANA_LEECHING];
				GV.ingameCore.spellCaster.stats.spentManaOnArmorTearingGem += resultingComponentCosts[GemComponentType.ARMOR_TEARING] - sourceComponentCosts[GemComponentType.ARMOR_TEARING];
				
				GV.ingameCore.spellCaster.stats.highestGradeGemCreated = Math.max(resultingGem.grade.g() + 1, GV.ingameCore.spellCaster.stats.highestGradeGemCreated);
				GV.ingameCore.stats.gemHighestMaxDamage = Math.max(GV.ingameCore.stats.gemHighestMaxDamage, resultingGem.sd2_CompNumMod.damageMax.g());
				
				return resultingGem;
			}
			catch(error: Error) {
				SB.playSound("sndalert");
				GV.vfxEngine.createFloatingText4(GV.main.mouseX, (GV.main.mouseY < 60) ? Number(GV.main.mouseY + 30) : Number(GV.main.mouseY - 20), "An error occured!", 16768392, 12, "center", Math.random() * 3 - 1.5, -4 - Math.random() * 3, 0, 0.55, 12, 0, 1000);
				GemsmithMod.logger.log("PerformCombineFrominstructions", "Caught an exception!");
				GemsmithMod.logger.log("PerformCombineFrominstructions", error.message);
				GemsmithMod.logger.log("PerformCombineFrominstructions", error.getStackTrace());
				return sourceGem;
			}
			return sourceGem;
		}

		// Takes a gem, carefully performs the combine, returns the new gem
		// Also handles gem bitmap creation
		public function virtualCombineGem(recipe: Recipe, gem:Gem): Gem
		{
			if (recipe.type == "Combine")
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
			}

			// In case of failure we just return the source gem
			var resultingGem:Gem = performCombineFromRecipe(recipe, gem) || gem;
			if (resultingGem != null)
			{
				resultingGem.recalculateSds();
				GV.gemBitmapCreator.giveGemBitmaps(resultingGem);
			}

			if (recipe.type == "Combine")
			{
				// Restore the modified range
				vRange4 = resultingGem.sd4_IntensityMod.range.g();
				vRange5 = resultingGem.sd5_EnhancedOrTrapOrLantern.range.g();
				resultingGem.rangeRatio.s(vRangeRatio);
				resultingGem.sd4_IntensityMod.range.s(vRange4 * resultingGem.rangeRatio.g());
				resultingGem.sd5_EnhancedOrTrapOrLantern.range.s(vRange5 * resultingGem.rangeRatio.g());
			}

			return resultingGem;
		}
		
		// Creates a gem from scratch
		public function conjureGem(recipe:Recipe, gemType:int, baseGrade:int = 0): Gem
		{
			var baseGem: Gem = null;
			
			if (recipe.type == "Combine")
			{
				baseGem = conjurePureGem(gemType, baseGrade);
				if (baseGem == null)
					return null;
			}
				
			var totalRecipeCost:Number = totalCombineCost(recipe, baseGem);
			if (GV.ingameCore.getMana() < totalRecipeCost)
				return baseGem;
				
			baseGem = virtualCombineGem(recipe, baseGem);
			
			GV.ingameCore.changeMana( -totalRecipeCost, false, true);
			return baseGem;
		}
		
		private function conjurePureGem(gemType: int, grade: int = 0): Gem
		{
			if (GV.ingameCore.getMana() < GV.ingameCore.gemCreatingBaseManaCosts[grade])
				return null;
				
			var baseGem:Gem = GV.ingameCore.creator.createGem(grade, gemType, true);
			GV.ingameCore.changeMana( -GV.ingameCore.gemCreatingBaseManaCosts[grade], false, true);
			
			return baseGem;
		}
		
		private function createPureGem(gemType: int, grade: int = 0): Gem
		{
			var baseGem:Gem = GV.ingameCore.creator.createGem(grade, gemType, false);
			
			return baseGem;
		}
		
		public function gemTypesAvailable(types: Array): Boolean
		{
			var allPass:Boolean = true;
			for each(var type: int in types)
				allPass = allPass && gemTypeAvailable(type);
			return allPass;
		}
		
		public function gemTypeAvailable(type: int): Boolean
		{
			return GV.ingameCore.arrIsSpellBtnVisible[type+6];
		}
		
		// A helper method for summing two gems' component costs
		private function addByComponentCosts(cc1: Array, cc2: Array): Array
		{
			var cc3: Array = new Array(0, 0, 0, 0, 0, 0);/*Gem component costs*/
			for(var c: int = 0; c < cc3.length; c++)
				cc3[c] = cc1[c]+cc2[c];
			return cc3;
		}

		public function totalCombineCost(recipe: Recipe, sourceGem:Gem): Number
		{
			var sourceGemCost: Number;
			if (recipe.type == "Spec")
			{
				sourceGemCost = GV.ingameCore.gemCreatingBaseManaCosts[0];
				return sourceGemCost * (recipe.value) + GV.ingameCore.gemCombiningManaCost.g() * recipe.combines;
			}
			else if (recipe.type == "Combine")
			{
				sourceGemCost = sourceGem.cost.g();
				return sourceGemCost * (recipe.value - 1) + GV.ingameCore.gemCombiningManaCost.g() * recipe.combines;
			}
			return sourceGem.cost.g() * (recipe.value - 1) + GV.ingameCore.gemCombiningManaCost.g() * recipe.combines;
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
		
		public function getRecipeByName(name: String): Recipe
		{
			for each(var rec:Recipe in this.recipes)
			{
				if (rec.name == name)
				{
					return rec;
				}
			}
			return Recipe.emptyRecipe;
		}
		
		public function totalCombineCostCurrent(sourceGem:Gem): Number
		{
			if (this.currentRecipeIndex != -1)
			{
				var currRecipe: Recipe = currentRecipe();
				return totalCombineCost(currRecipe, sourceGem);
			}
			else
				return NaN;
		}

		// Either:
		// 1 - Processes the hotkey if it's bound to a Gemsmith function
		// 2 - Substitutes the KeyCode from Gemsmith_config.json
		// Then it either lets the base game handler to run (so it then fires the function with the substituted KeyCode)
		// or stops the base game's handler
		private function eh_interceptKeyboardEvent(event:IngameKeyDownEvent): void
		{
			var pE:KeyboardEvent = event.eventArgs.event;

			if(GemsmithMod.bezel.keybindManager.getHotkeyValue("Gemsmith: Cycle selected recipe left").matches(pE))
			{
				cycleSelectedRecipe(-1);
				event.eventArgs.continueDefault = false;
			}
			else if(GemsmithMod.bezel.keybindManager.getHotkeyValue("Gemsmith: Cycle selected recipe right").matches(pE))
			{
				cycleSelectedRecipe(1);
				event.eventArgs.continueDefault = false;
			}
			else if(GemsmithMod.bezel.keybindManager.getHotkeyValue("Gemsmith: Perform combine").matches(pE))
			{
				castCombineOnMouse();
				event.eventArgs.continueDefault = false;
			}
			else if (GemsmithMod.bezel.keybindManager.getHotkeyValue("Gemsmith: Reload recipes").matches(pE))
			{
				reloadEverything();
				event.eventArgs.continueDefault = false;
			}
			/*else if(pE.keyCode == GemsmithMod.bezel.keybindManager.getHotkeyValue("Gemsmith: Conjure gem"))
			{
				conjureGemOnMouse();
				event.eventArgs.continueDefault = false;
			}*/
			else if(GemsmithMod.bezel.keybindManager.getHotkeyValue("Show/hide info panels").matches(pE))
			{
				if (this.infoPanelState == InfoPanelState.HIDDEN)
				{
					this.infoPanelState = InfoPanelState.BASEGAME;
				}
				else if (this.infoPanelState == InfoPanelState.BASEGAME)
				{
					this.infoPanelState = InfoPanelState.GEMSMITH;
					event.eventArgs.continueDefault = false;
				}
				else
				{
					this.infoPanelState = InfoPanelState.HIDDEN;
				}
			}
		}

		// Gemsmith adds its own tooltips in this method
		private function eh_ingameGemInfoPanelFormed(event:IngameGemInfoPanelFormedEvent): void
		{
			//GemsmithMod.logger.log("eh_GemInfoPanelFormed", "Responding to an event!");
			var vIp:McInfoPanel = event.eventArgs.infoPanel as McInfoPanel;
			var gem:Gem = event.eventArgs.gem as Gem;
			var numberFormatter:Object = event.eventArgs.numberFormatter;
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
					vIp.addTextfield(10526880, "Mod version: " + GemsmithMod.instance.prettyVersion(), true, 7);
			}
			//GemsmithMod.logger.log("eh_GemInfoPanelFormed", "Done with the event!");
		}
		
		private function prepareFoldersAndLogger(): void
		{
			var storageFolder:File = storage.resolvePath("Gemsmith");
			if (!storageFolder.isDirectory)
			{
				GemsmithMod.logger.log("PrepareFolders", "Creating ./Gemsmith");
				storageFolder.createDirectory();
			}
				
			var recipesFolder:File = storage.resolvePath("Gemsmith/recipes");
			if(!recipesFolder.isDirectory)
			{
				GemsmithMod.logger.log("PrepareFolders", "Creating ./recipes");
				recipesFolder.createDirectory();
				var exampleRecipeFile:File = storage.resolvePath("Gemsmith/recipes/example_8combine.txt");
				var eRFStream:FileStream = new FileStream();
				eRFStream.open(exampleRecipeFile, FileMode.WRITE);
				eRFStream.writeUTFBytes("Equations:\r\n(val=1)0=g1k\r\n(val=2)1=0+0\r\n(val=3)2=1+0\r\n(val=4)3=2+0\r\n(val=6)4=3+1\r\n(val=8)5=4+1\r\n\r\nkc000008-gemforcev2.0.0-table_kgcexact");
				eRFStream.close();
			}
		}
		
		public function reloadEverything(): void
		{
			formRecipeList();
			GV.vfxEngine.createFloatingText4(GV.main.mouseX,GV.main.mouseY < 60?Number(GV.main.mouseY + 30):Number(GV.main.mouseY - 20),"Reloaded recipes & config!",99999999,20,"center",0,0,0,0,24,0,1000);
			SB.playSound("sndalert");
		}
		
		private function checkForUpdates(): void
		{
			if(!settings.retrieveBoolean("Check for updates"))
				return;
			
			GemsmithMod.logger.log("CheckForUpdates", "Mod version: " + GemsmithMod.instance.prettyVersion());
			GemsmithMod.logger.log("CheckForUpdates", "Checking for updates...");
			var repoAddress:String = "https://api.github.com/repos/gemforce-team/gemsmith/releases/latest";
			var request:URLRequest = new URLRequest(repoAddress);

			var loader:URLLoader = new URLLoader();
			var localThis:GCFWGemsmith = this;
			
			loader.addEventListener(Event.COMPLETE, function(e:Event): void {
				var latestTag:Object = JSON.parse(loader.data).tag_name;
				var latestVersion:String = latestTag.replace(/[v]/gim, '').split('-')[0];
				localThis.updateAvailable = (latestVersion != GemsmithMod.instance.VERSION);
				GemsmithMod.logger.log("CheckForUpdates", localThis.updateAvailable ? "Update available! " + latestTag : "Using the latest version: " + latestTag);
			});
			loader.addEventListener(IOErrorEvent.IO_ERROR, function(e:IOErrorEvent): void {
				GemsmithMod.logger.log("CheckForUpdates", "Caught an error when checking for updates!");
				GemsmithMod.logger.log("CheckForUpdates", e.text);
			});
			
			loader.load(request);
		}
		
		private function addEventListeners(): void
		{
			GemsmithMod.bezel.addEventListener(EventTypes.INGAME_GEM_INFO_PANEL_FORMED, eh_ingameGemInfoPanelFormed);
			GemsmithMod.bezel.addEventListener(EventTypes.INGAME_KEY_DOWN, eh_interceptKeyboardEvent);
			GemsmithMod.bezel.addEventListener(EventTypes.INGAME_NEW_SCENE, formRecipeList);
			GemsmithMod.gameObjects.main.stage.addEventListener(MouseEvent.MOUSE_WHEEL, eh_ingameWheelScrolled, true, 10);
			GemsmithMod.gameObjects.main.stage.addEventListener(KeyboardEvent.KEY_DOWN, eh_keyboadKeyDown, true);
			GemsmithMod.gameObjects.main.stage.addEventListener(KeyboardEvent.KEY_UP, eh_keyboadKeyUp, true);
		}
		
		public function unload(): void
		{
			removeEventListeners();
			this.recipes = null;
		}
		
		public function eh_ingameWheelScrolled(e: MouseEvent): void
		{
			if (!ctrlKeyHeld || !GV.ingameCore.controller.getGemUnderPointer(false))
				return;
				
			if (e.delta > 0)
				cycleSelectedRecipe( -1);
			else
				cycleSelectedRecipe(1);
				
			e.stopImmediatePropagation();
		}
		
		public function eh_keyboadKeyDown(e: KeyboardEvent): void
		{
			this.ctrlKeyHeld = e.ctrlKey;
		}
		
		public function eh_keyboadKeyUp(e: KeyboardEvent): void
		{
			this.ctrlKeyHeld = e.ctrlKey;
		}
		
		private function removeEventListeners(): void
		{
			GemsmithMod.bezel.removeEventListener(EventTypes.INGAME_GEM_INFO_PANEL_FORMED, eh_ingameGemInfoPanelFormed);
			GemsmithMod.bezel.removeEventListener(EventTypes.INGAME_KEY_DOWN, eh_interceptKeyboardEvent);
			GemsmithMod.bezel.removeEventListener(EventTypes.INGAME_NEW_SCENE, formRecipeList);
			GemsmithMod.gameObjects.main.stage.removeEventListener(MouseEvent.MOUSE_WHEEL, eh_ingameWheelScrolled, true);
			GemsmithMod.gameObjects.main.stage.removeEventListener(KeyboardEvent.KEY_DOWN, eh_keyboadKeyDown, true);
			GemsmithMod.gameObjects.main.stage.removeEventListener(KeyboardEvent.KEY_UP, eh_keyboadKeyUp, true);
		}
		
		private function registerKeybinds(): void
		{
			GemsmithMod.bezel.keybindManager.registerHotkey("Gemsmith: Cycle selected recipe left", new Keybind("page_up"));
			GemsmithMod.bezel.keybindManager.registerHotkey("Gemsmith: Perform combine", new Keybind("home"));
			GemsmithMod.bezel.keybindManager.registerHotkey("Gemsmith: Cycle selected recipe right", new Keybind("page_down"));
			GemsmithMod.bezel.keybindManager.registerHotkey("Gemsmith: Reload recipes", new Keybind("alt+home"));
			// GemsmithMod.bezel.keybindManager.registerHotkey("Gemsmith: Conjure gem", 89);
		}
	}
}
