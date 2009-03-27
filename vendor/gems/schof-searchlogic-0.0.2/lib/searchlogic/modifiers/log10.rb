module Searchlogic
  module Modifiers
    class Log10 < Base
      class << self
        def return_type
          :float
        end
      end
    end
  end
end