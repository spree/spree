module Searchlogic
  module Modifiers
    class Floor < Base
      class << self
        def modifier_names
          super + ["round_down"]
        end
        
        def return_type
          :integer
        end
      end
    end
  end
end