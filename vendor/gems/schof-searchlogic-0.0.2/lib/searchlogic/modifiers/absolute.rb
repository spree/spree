module Searchlogic
  module Modifiers
    class Absolute < Base
      class << self
        def modifier_names
          super + ["abs"]
        end
        
        def return_type
          :integer
        end
      end
    end
  end
end