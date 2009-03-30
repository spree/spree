module Searchlogic
  module Modifiers
    class Round < Base
      class << self
        def return_type
          :integer
        end
      end
    end
  end
end