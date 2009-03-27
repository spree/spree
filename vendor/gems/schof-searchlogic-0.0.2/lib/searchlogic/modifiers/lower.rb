module Searchlogic
  module Modifiers
    class Lower < Base
      class << self
        def modifier_names
          super + ["downcase", "lcase"]
        end
        
        def return_type
          :string
        end
      end
    end
  end
end