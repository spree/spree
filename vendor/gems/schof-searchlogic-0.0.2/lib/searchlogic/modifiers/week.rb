module Searchlogic
  module Modifiers
    class Week < Base
      class << self
        def return_type
          :integer
        end
      end
    end
  end
end