module Spree
  module Core
    module Search
      class Base
        attr_accessor :properties
        attr_accessor :current_user
        attr_accessor :current_currency
        attr_accessor :params

        def initialize(params)
          @params = params
          self.current_currency = Spree::Config[:currency]
        end
      end
    end
  end
end
