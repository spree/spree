require File.join(File.dirname(__FILE__), *%w[helper])

Story "I can create a cell",
  %(As a game producer
    I want to create a cell
    So that I can show the grid to people), :steps_for => :life do
  
  Scenario "nothing to see here" do
    Given "a game with dimensions", 3, 3 do |rows,cols|
      @game = Game.new(rows,cols)
    end
    
    Then "the grid should look like", %(
      ...
      ...
      ...
    )
  end
  
  Scenario "all on its lonesome" do
    Given "a game with dimensions", 2, 2
    When "I create a cell at", 1, 1 do |row,col|
      @game.create_at(row,col)
    end
    Then "the grid should look like", %(
      ..
      .X
    )
  end
  
  Scenario "the grid has three cells" do
    Given "a game with dimensions", 3, 3
    When "I create a cell at", 0, 0
    When "I create a cell at", 0, 1
    When "I create a cell at", 2, 2
    Then "the grid should look like", %(
      XX.
      ...
      ..X
    )
  end
  
  Scenario "more cells more more" do
    GivenScenario "the grid has three cells"
    When "I create a cell at", 2, 0
    Then "the grid should look like", %(
      XX.
      ...
      X.X
    )
  end
end
