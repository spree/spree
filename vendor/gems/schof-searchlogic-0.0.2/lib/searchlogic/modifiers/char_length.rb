module Searchlogic
  module Modifiers
    class CharLength < Base
      class << self
        def modifier_names
          super + ["length"]
        end
        
        def return_type
          :integer
        end
      end
    end
  end
end