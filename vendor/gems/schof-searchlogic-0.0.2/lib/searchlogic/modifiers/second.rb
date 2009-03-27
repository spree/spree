module Searchlogic
  module Modifiers
    class Second < Base
      class << self
        def modifier_names
          super + ["sec"]
        end
        
        def return_type
          :integer
        end
      end
    end
  end
end