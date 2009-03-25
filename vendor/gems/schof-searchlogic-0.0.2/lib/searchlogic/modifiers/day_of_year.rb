module Searchlogic
  module Modifiers
    class DayOfYear < Base
      class << self
        def modifier_names
          super + ["doy"]
        end
        
        def return_type
          :integer
        end
      end
    end
  end
end