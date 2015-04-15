module Spree
  module Core
    module ControllerHelpers
      module Store
        extend ActiveSupport::Concern

        included do
          helper_method :current_currency
          helper_method :current_store
          helper_method :current_tax_zone
        end

        def current_currency
          Spree::Config[:currency]
        end

        def current_store
          @current_store ||= Spree::Store.current(request.env['SERVER_NAME'])
        end

        def current_tax_zone
          if current_order
            current_order.tax_zone
          else
            Spree::Zone.default_tax
          end
        end
      end
    end
  end
end
