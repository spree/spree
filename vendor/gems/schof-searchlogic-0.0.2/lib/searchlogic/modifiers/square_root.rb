module Searchlogic
  module Modifiers
    class SquareRoot < Base
      class << self
        def modifier_names
          super + ["sqrt", "sq_rt"]
        end
        
        def return_type
          :float
        end
      end
    end
  end
end