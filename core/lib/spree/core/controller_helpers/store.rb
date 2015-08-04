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
