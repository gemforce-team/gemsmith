#!/bin/bash
set -e

gem_recipes_repo='../../gem-recipes'
zipfolder='Gemforce recipes'

rm -rf "${zipfolder}"
mkdir "${zipfolder}"

for folder in ${gem_recipes_repo}/{leech,crit,gcfw/bleed}-combine; do
    cp -r ${folder} "${zipfolder}"
done
cp Instructions.txt "${zipfolder}"

zip -r Gemforce.recipes.zip "${zipfolder}"

rm -r "${zipfolder}"
