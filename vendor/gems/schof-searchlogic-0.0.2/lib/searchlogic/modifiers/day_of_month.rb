module Searchlogic
  module Modifiers
    class DayOfMonth < Base
      class << self
        def modifier_names
          super + ["dom"]
        end
        
        def return_type
          :integer
        end
      end
    end
  end
end