module Searchlogic
  module Modifiers
    class Octal < Base
      class << self
        def modifier_names
          super + ["oct"]
        end
        
        def return_type
          :float
        end
      end
    end
  end
end