module Searchlogic
  module Modifiers
    class Upper < Base
      class << self
        def modifier_names
          super + ["upcase", "ucase"]
        end
        
        def return_type
          :string
        end
      end
    end
  end
end