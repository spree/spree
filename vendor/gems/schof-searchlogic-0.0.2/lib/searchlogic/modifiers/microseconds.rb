module Searchlogic
  module Modifiers
    class Microseconds < Base
      class << self
        def return_type
          :integer
        end
      end
    end
  end
end