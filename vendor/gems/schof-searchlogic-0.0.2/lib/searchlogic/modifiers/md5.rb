module Searchlogic
  module Modifiers
    class Md5 < Base
      class << self
        def return_type
          :string
        end
      end
    end
  end
end