module Searchlogic
  module Modifiers
    class Hour < Base
      class << self
        def return_type
          :integer
        end
      end
    end
  end
end