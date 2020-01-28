# Gemsmith

## Description
Gemsmith is a game modification for GCFW.

Same as in the previous game, combining a gem with itself is not always the best way to upgrade it. Thanks to the work done at https://github.com/gemforce-team/gemforce, certain recipes - specific orders of duplicating\combining operations - have been discovered that result in a stronger gem than you'd get by U-upgrading, for the same cost. The catch is that it might take upwards of hundreds of operations to perform some of the better recipes.

Gemsmith allows you to skip performing these operations manually, instead it performs the combine on your gem automatically, spending mana accordingly. Unlike wGemCombiner this is done ingame, completely bypassing UI interactions and using no extra inventory slots. 

This is merely a time saving and QOL mod, exactly the same results can be achieved without it, albeit much slower and with more effort. Mana expenditure stats and achievements should be tracked appropriately, [submit an issue](https://github.com/gemforce-team/gemsmith/issues) if you find that something's off!


## Features
* A combine can be performed on a gem anywhere: in your inventory, in towers, lanterns, traps, amplifiers and in the enrage slot.

* The recipes are loaded from a dedicated folder, you can have as many as you need and switch between them with hotkeys. These recipes are defined in a certain format, devised for gemforce, an example recipe is generated on startup. Keep in mind that at the moment only "combine" recipes are supported - upgrading one gem.

* Gemsmith also includes a configuration file that allows you to rebind hotkeys. This includes both Gemsmith's own functions and base game's hotkeys.

* Gemsmith keeps a log of the last session, if you see a floating message saying that an error has occured, there might be more information in there. Consult the README included with releases for details.


## Installation
Installation instructions are included in a README in each release.

The modification is installed by applying a diff patch to the game's SWF file.

This is achieved using Courgette: https://blog.chromium.org/2009/07/smaller-is-faster-and-safer-too.html

Courgette repo: https://chromium.googlesource.com/chromium/src/courgette/+/master


# Bug reports and feedback
Please submit an issue to [The issue tracker](https://github.com/gemforce-team/gemsmith/issues) if you encounter a bug and there isn't already an open issue about it.

You can find me on GemCraft's Discord server: https://discord.gg/ftyaJhx - Hellrage#5076


# Disclaimer
This is not an official modification.

GemCraft - Frostborn Wrath is developed and owned by [gameinabottle](http://gameinabottle.com/)


# Credits
12345ieee for helping with testing, ideas, advice on using gemforce and combine logic

piotrj3 for help with decompilation and testing

wGemCombiner team for creating the predecessor

gemforce team for working out the combine recipes
