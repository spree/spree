module Searchlogic
  module Modifiers
    class Rtrim < Base
      class << self
        def modifier_names
          super + ["rstrip"]
        end
        
        def return_type
          :string
        end
      end
    end
  end
end