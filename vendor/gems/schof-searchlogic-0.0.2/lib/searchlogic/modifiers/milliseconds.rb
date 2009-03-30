module Searchlogic
  module Modifiers
    class Milliseconds < Base
      class << self
        def return_type
          :integer
        end
      end
    end
  end
end