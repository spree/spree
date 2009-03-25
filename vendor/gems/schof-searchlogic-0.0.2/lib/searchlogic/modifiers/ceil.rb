module Searchlogic
  module Modifiers
    class Ceil < Base
      class << self
        def modifier_names
          super + ["round_up"]
        end
        
        def return_type
          :integer
        end
      end
    end
  end
end