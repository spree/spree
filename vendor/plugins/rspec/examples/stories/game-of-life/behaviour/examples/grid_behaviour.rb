describe Grid do
  it 'should be empty when created' do
    # given
    expected_contents = [
      [0, 0, 0],
      [0, 0, 0]
    ]
    grid = Grid.new(2, 3)
    
    # when
    contents = grid.contents
    
    # then
    contents.should == expected_contents
  end
  
  it 'should compare equal based on its contents' do
    # given
    grid1 = Grid.new(2, 3)
    grid2 = Grid.new(2, 3)
    
    # then
    grid1.should == grid2
  end
  
  it 'should be able to replace its contents' do
    # given
    grid = Grid.new(2,2)
    new_contents = [[0,1,0], [1,0,1]]
    
    # when
    grid.contents = new_contents
    
    # then
    grid.contents.should == new_contents
    grid.rows.should == 2
    grid.columns.should == 3
  end
  
  it 'should add an organism' do
    # given
    grid = Grid.new(2, 2)
    expected = Grid.new(2, 2)
    expected.contents = [[1,0],[0,0]]
    
    # when
    grid.create_at(0,0)
    
    # then
    grid.should == expected
  end
  
  it 'should create itself from a string' do
    # given
    expected = Grid.new 3, 3
    expected.create_at(0,0)
    expected.create_at(1,0)
    expected.create_at(2,2)
    
    # when
    actual = Grid.from_string "X.. X.. ..X"
    
    # then
    actual.should == expected
  end
end
