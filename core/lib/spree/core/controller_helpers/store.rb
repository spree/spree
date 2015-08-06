module Spree
  module Core
    module ControllerHelpers
      module Store
        extend ActiveSupport::Concern

        included do
          helper_method :current_currency
          helper_method :current_store
          helper_method :current_price_options
        end

        def current_currency
          Spree::Config[:currency]
        end

        def current_store
          @current_store ||= Spree::Store.current(request.env['SERVER_NAME'])
        end

        # Return a Hash of things that influence the prices displayed in your shop.
        #
        # By default, the only thing that influences prices that is the current order's +tax_zone+
        # (to facilitate differing prices depending on VAT rate for digital products in Europe, see
        # https://github.com/spree/spree/pull/6295 and https://github.com/spree/spree/pull/6662).
        #
        # If your prices depend on something else, overwrite this method and add
        # more key/value pairs to the Hash it returns.
        #
        # Be careful though to also patch the following parts of Spree accordingly:
        #
        # * `Spree::VatPriceCalculation#gross_amount`
        # * `Spree::LineItem#update_price`
        # * `Spree::Stock::Estimator#taxation_options_for`
        # * Subclass the `DefaultTax` calculator
        #
        def current_price_options
          {
            tax_zone: current_tax_zone
          }
        end

        private

        def current_tax_zone
          current_order.try(:tax_zone) || Spree::Zone.default_tax
        end
      end
    end
  end
end
