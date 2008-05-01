Story: I can kill a cell

As a game producer
I want to kill a cell
So that when I make a mistake I dont have to start again

Scenario: bang youre dead

Given the grid looks like
XX.
.X.
..X
When I destroy the cell at 0, 1
Then the grid should look like
X..
.X.
..X
