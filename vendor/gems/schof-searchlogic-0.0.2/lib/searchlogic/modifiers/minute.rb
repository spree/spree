module Searchlogic
  module Modifiers
    class Minute < Base
      class << self
        def modifier_names
          super + ["min"]
        end
        
        def return_type
          :integer
        end
      end
    end
  end
end