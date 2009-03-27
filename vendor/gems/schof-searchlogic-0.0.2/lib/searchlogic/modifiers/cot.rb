module Searchlogic
  module Modifiers
    class Cot < Base
      class << self
        def modifier_names
          super + ["cotangent"]
        end
        
        def return_type
          :float
        end
      end
    end
  end
end