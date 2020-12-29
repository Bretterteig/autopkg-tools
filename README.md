## Cache-Cleaner
### What does it do?
The tool scans the Autopkg cache for files/folders that haven't been used in a long time without corrupting the cache/programs.
### Requirements
Just a munki repo
### Usage
Simply run it. There are three options you can edit within the tool to change its behaviour.
## Autopkg-Multithreaded
### What does it do?
When an Autopkg repository gets large it takes longer and longer to process all recipes. Autopkg and the tools it uses are inherintly single core. This wrapper schedules and monitors multiple instances of Autopkg to increase its performance and lets it scale to the hardware/network it is running on.
### Requirements
Simply Autopkg
### Usage
If you decide to simply start it, it will run all recipes that it can find in all RECIPE_OVERRIDE_DIRS. You can override this behaviour by specifing a recipe list or a folder that should be used.
Additional info can be found in the help function using "-h"