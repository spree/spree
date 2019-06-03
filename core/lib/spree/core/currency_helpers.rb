module Spree
  module CurrencyHelpers
    def self.included(receiver)
      receiver.send :helper_method, :supported_currencies
    end

    def supported_currencies
      Spree::Config[:supported_currencies].split(',').map { |code| ::Money::Currency.find(code.strip) }
    end
  end
end
