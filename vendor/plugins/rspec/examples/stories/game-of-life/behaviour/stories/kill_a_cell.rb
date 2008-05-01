require File.join(File.dirname(__FILE__), *%w[helper])

Story 'I can kill a cell',
  %(As a game producer
  I want to kill a cell
  So that when I make a mistake I don't have to start again), :steps_for => :life do
  
  Scenario "bang, you're dead" do
    
    Given 'a game that looks like', %(
      XX.
      .X.
      ..X
    ) do |dots|
      @game = Game.from_string dots
    end
    When 'I destroy the cell at', 0, 1 do |row,col|
      @game.destroy_at(row,col)
    end
    Then 'the grid should look like', %(
      X..
      .X.
      ..X
    )
  end
end
