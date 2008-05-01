Story: cells with more than three neighbours die

As a game producer
I want cells with more than three neighbours to die
So that I can show the people with money how we are getting on

Scenario: blink

Given the grid looks like
.....
...XX
...XX
.XX..
.XX..
When the next step occurs
Then the grid should look like
.....
...XX
....X
.X...
.XX..
