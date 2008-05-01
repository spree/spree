Story: I can create a cell

As a game producer
I want to create a cell
So that I can show the grid to people

Scenario: nothing to see here

Given a 3 x 3 game
Then the grid should look like
...
...
...

Scenario: all on its lonesome

Given a 3 x 3 game
When I create a cell at 1, 1
Then the grid should look like
...
.X.
...

Scenario: the grid has three cells

Given a 3 x 3 game
When I create a cell at 0, 0
and I create a cell at 0, 1
and I create a cell at 2, 2
Then the grid should look like
XX.
...
..X

Scenario: more cells more more

Given the grid has three cells
When I create a celll at 3, 1
Then the grid should look like
XX.
..X
..X
