require 'life'

describe Game do
  it 'should have a grid' do
    # given
    game = Game.new(5, 5)
    
    # then
    game.grid.should be_kind_of(Grid)
  end
  
  it 'should create a cell' do
    # given
    game = Game.new(2, 2)
    expected_grid = Grid.from_string( 'X. ..' )
    
    # when
    game.create_at(0, 0)
    
    # then
    game.grid.should == expected_grid
  end
  
  it 'should destroy a cell' do
    # given
    game = Game.new(2,2)
    game.grid = Grid.from_string('X. ..')
    
    # when
    game.destroy_at(0,0)
    
    # then
    game.grid.should == Grid.from_string('.. ..')
  end
end
