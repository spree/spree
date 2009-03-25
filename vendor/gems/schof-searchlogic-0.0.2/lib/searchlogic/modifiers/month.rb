module Searchlogic
  module Modifiers
    class Month < Base
      class << self
        def modifier_names
          super + ["mon"]
        end
        
        def return_type
          :integer
        end
      end
    end
  end
end