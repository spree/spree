module Searchlogic
  module Modifiers
    class Tan < Base
      class << self
        def modifier_names
          super + ["tangent"]
        end
        
        def return_type
          :float
        end
      end
    end
  end
end