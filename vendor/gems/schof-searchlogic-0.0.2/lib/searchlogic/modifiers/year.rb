module Searchlogic
  module Modifiers
    class Year < Base
      class << self
        def return_type
          :integer
        end
      end
    end
  end
end