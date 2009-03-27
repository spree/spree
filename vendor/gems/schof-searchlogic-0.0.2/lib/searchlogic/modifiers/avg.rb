module Searchlogic
  module Modifiers
    class Avg < Base
      class << self
        def modifier_names
          super + ["average"]
        end
        
        def return_type
          :float
        end
      end
    end
  end
end