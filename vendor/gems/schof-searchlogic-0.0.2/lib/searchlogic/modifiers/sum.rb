module Searchlogic
  module Modifiers
    class Sum < Base
      class << self
        def return_type
          :float
        end
      end
    end
  end
end