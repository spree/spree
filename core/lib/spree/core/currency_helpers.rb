module Spree
<<<<<<< HEAD
  module Core
    module CurrencyHelpers
      def self.included(receiver)
        receiver.send :helper_method, :supported_currencies
      end

      def supported_currencies
        Spree::Config[:supported_currencies].split(',').map { |code| ::Money::Currency.find(code.strip) }
      end
=======
  module CurrencyHelpers
    def self.included(receiver)
      receiver.send :helper_method, :supported_currencies
    end

    def supported_currencies
      Spree::Config[:supported_currencies].split(',').map { |code| ::Money::Currency.find(code.strip) }
>>>>>>> 4eadff5c14... Adds spree_multi_currency logic to spree 4.0
    end
  end
end
