module Spree
  module Core
    module ControllerHelpers
      module Store
        extend ActiveSupport::Concern

        included do
          if defined?(helper_method)
            helper_method :current_store
            helper_method :current_price_options
          end

          prepend_before_action :raise_record_not_found_if_store_is_not_found
        end

        def current_store
          @current_store ||= current_store_finder.new(url: request.env['SERVER_NAME']).execute
        end

        def store_locale
          @store_locale ||= current_store.default_locale
        end

        def ensure_current_store(object)
          return if object.nil?

          if object.has_attribute?(:store_id)
            if object.store.present? && object.store != current_store
              raise Spree.t('errors.messages.store_is_already_set')
            else
              object.store = current_store
            end
          elsif object.class.method_defined?(:stores) && object.stores.exclude?(current_store)
            object.stores << current_store
          end
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
          @current_tax_zone ||= begin
            zone = @current_order&.tax_zone || Spree::Zone.default_tax
            Spree::Current.zone = zone
            zone
          end
        end

        def current_store_finder
          Spree.current_store_finder
        end

        def raise_record_not_found_if_store_is_not_found
          return if skip_store_lookup?

          raise ActiveRecord::RecordNotFound if current_store.nil?
        end

        def skip_store_lookup?
          Spree.root_domain.present? && Spree.root_domain.include?(request.env['SERVER_NAME'])
        end
      end
    end
  end
end
