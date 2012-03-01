# This class is used to find all of the possible combinations multiple arrays
#   http://en.wikipedia.org/wiki/Cartesian_product

module Spree
  module Core
    class CartesianArray < Array
    
      def initialize(*args)
        super args
      end
      
      def product(*args)
        result = [[]]
        args += self
        while [] != args
          t, result = result, []
          b, *args = args
          t.each do |a|
            b.each do |n|
              result << a + [n]
            end
          end
        end
        result
      end
    
    end
  end
end
