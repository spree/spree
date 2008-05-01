class Grid
  
  attr_accessor :contents
  
  def initialize(rows, cols)
    @contents = []
    rows.times do @contents << [0] * cols end
  end
  
  def rows
    @contents.size
  end
  
  def columns
    @contents[0].size
  end
  
  def ==(other)
    self.contents == other.contents
  end
  
  def create_at(row,col)
    @contents[row][col] = 1
  end
  
  def destroy_at(row,col)
    @contents[row][col] = 0
  end
  
  def self.from_string(str)
    row_strings = str.split(' ')
    grid = new(row_strings.size, row_strings[0].size)
    
    row_strings.each_with_index do |row, row_index|
      row_chars = row.split(//)
      row_chars.each_with_index do |col_char, col_index|
        grid.create_at(row_index, col_index) if col_char == 'X'
      end
    end
    return grid
  end
  
end
