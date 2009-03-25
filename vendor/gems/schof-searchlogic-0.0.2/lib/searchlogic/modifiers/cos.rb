module Searchlogic
  module Modifiers
    class Cos < Base
      class << self
        def modifier_names
          super + ["cosine"]
        end
        
        def return_type
          :float
        end
      end
    end
  end
end