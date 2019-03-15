module Spree
  module Cart
    class EstimateShippingRates
      prepend Spree::ServiceModule::Base

      def call(order:, country_iso: nil)
        country_id = if country_iso.present?
          ::Spree::Country.by_iso(country_iso).id
        else
          ::Spree::Country.default.id
        end

        dummy_order = order.dup
        dummy_order.line_items = order.line_items
        dummy_order.ship_address = ::Spree::Address.new(country_id: country_id)
        packages = ::Spree::Stock::Coordinator.new(dummy_order).packages
        estimator = ::Spree::Stock::Estimator.new(dummy_order)
        shipping_rates = if order.line_items.any? && packages.any?
                            estimator.shipping_rates(packages.first)
                          else
                            []
                          end

        success(shipping_rates)
      end
    end
  end
end
