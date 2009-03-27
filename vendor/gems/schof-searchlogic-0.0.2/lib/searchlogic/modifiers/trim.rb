module Searchlogic
  module Modifiers
    class Trim < Base
      class << self
        def modifier_names
          super + ["strip"]
        end
        
        def return_type
          :string
        end
      end
    end
  end
end