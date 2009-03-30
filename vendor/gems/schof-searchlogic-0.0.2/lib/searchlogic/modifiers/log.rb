module Searchlogic
  module Modifiers
    class Log < Base
      class << self
        def modifier_names
          super + ["ln"]
        end
        
        def return_type
          :float
        end
      end
    end
  end
end