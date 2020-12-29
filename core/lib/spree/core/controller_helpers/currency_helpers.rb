module Spree
  module Core
    module ControllerHelpers
      module CurrencyHelpers
        def self.included(receiver)
          receiver.send :helper_method, :supported_currencies
        end

        def supported_currencies
          current_store.supported_currencies_list
        end
      end
    end
  end
end
