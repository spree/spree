steps_for :life do
  Then "the grid should look like" do |dots|
    @game.grid.should == Grid.from_string(dots)
  end
end