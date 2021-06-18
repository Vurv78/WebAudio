# Contributing
Wanna add something to the addon? Here's some rules and steps for doing so.

## Checks
1. Make sure what you want to add doesn't already exist / has been fixed / has been assigned to someone else.
   1. Make an issue before trying to pr
2. Make sure you also document the stuff you're adding.
   1. Steam README
   2. Github README.md
   3. cl_webaudio.lua

## Rules
1. Do *NOT* use glua specific / garry syntax. Talking about !=, !, continue. (Yes, even continue.)
2. Make sure to comply with the linter.
   1. This means making sure there's no trailing whitespace.
   2. Having spaces after operators
   3. Avoiding use of globals, etc..

## Recommendations
Use glua enhanced for vscode. It's super useful and will help you with the syntax highlighting and ide sort of feel.

## Note
Changes may not be accepted depending on whether:
  1. The code isn't efficient
  2. I would rather implement it myself
  3. It has a controversial or breaking change