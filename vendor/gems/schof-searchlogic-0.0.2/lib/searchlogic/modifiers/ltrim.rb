module Searchlogic
  module Modifiers
    class Ltrim < Base
      class << self
        def modifier_names
          super + ["lstrip"]
        end
        
        def return_type
          :string
        end
      end
    end
  end
end