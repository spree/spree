module Spree
  module Core
    module ControllerHelpers
      module CurrencyHelpers
        def self.included(receiver)
          receiver.send :helper_method, :supported_currencies
          receiver.send :helper_method, :supported_currencies_for_all_stores
        end

        def supported_currencies
          current_store.supported_currencies_list
        end

        def supported_currencies_for_all_stores
          @supported_currencies_for_all_stores ||= begin
            (
              Spree::Store.pluck(:supported_currencies).map { |c| c&.split(',') }.flatten + Spree::Store.pluck(:default_currency)
            ).
              compact.uniq.map { |code| ::Money::Currency.find(code.strip) }
          end
        end
      end
    end
  end
end
