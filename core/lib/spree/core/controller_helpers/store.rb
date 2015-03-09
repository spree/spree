module Spree
  module Core
    module ControllerHelpers
      module Store
        extend ActiveSupport::Concern

        included do
          helper_method :current_currency
          helper_method :current_store
        end

        def current_currency
          Spree::Config[:currency]
        end

        def current_store
          @current_store ||= Spree::Store.current(request.env['SERVER_NAME'])
        end
      end
    end
  end
end
