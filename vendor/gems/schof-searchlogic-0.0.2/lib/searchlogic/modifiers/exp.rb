module Searchlogic
  module Modifiers
    class Exp < Base
      class << self
        def modifier_names
          super + ["exponential"]
        end
        
        def return_type
          :float
        end
      end
    end
  end
end