module Searchlogic
  module Modifiers
    class DayOfWeek < Base
      class << self
        def modifier_names
          super + ["dow"]
        end
        
        def return_type
          :integer
        end
      end
    end
  end
end