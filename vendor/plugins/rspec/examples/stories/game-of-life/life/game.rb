class Game
  attr_accessor :grid
  def initialize(rows,cols)
    @grid = Grid.new(rows, cols)
  end
  
  def create_at(row,col)
    @grid.create_at(row,col)
  end
  
  def destroy_at(row,col)
    @grid.destroy_at(row, col)
  end
  
  def self.from_string(dots)
    grid = Grid.from_string(dots)
    game = new(grid.rows, grid.columns)
    game.instance_eval do
      @grid = grid
    end
    return game
  end
end
