module Searchlogic
  module Modifiers
    class Count < Base
      class << self
        def return_type
          :integer
        end
      end
    end
  end
end