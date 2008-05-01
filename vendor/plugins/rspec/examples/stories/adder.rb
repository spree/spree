class Adder
  def initialize
    @addends = []
  end
  
  def <<(val)
    @addends << val
  end
  
  def sum
    @addends.inject(0) { |sum_so_far, val| sum_so_far + val }
  end
end