module SpreeEasyPost
  # Quotes a delivery method from EasyPost. Each method maps to one carrier
  # service (metadata: `carrier` + `service`, e.g. UPS/Ground) — "Ground" and
  # "Express" are two DeliveryMethods sharing this provider, and the shared
  # shipment call below means quoting both costs one API round-trip.
  class DeliveryRateProvider < Spree::DeliveryRateProvider::Base
    def self.integration_class
      'SpreeEasyPost::Integration'
    end

    def self.provider_name
      SpreeEasyPost::PROVIDER_NAME
    end

    # EasyPost quotes parcel carriers only.
    def self.fulfillment_types
      ['shipping']
    end

    # A rating failure must never break checkout: any API error suppresses
    # this method (the customer still sees calculator-priced options) and is
    # reported for observability rather than raised into the rate refresh.
    #
    # @param package [Spree::Stock::Package]
    # @return [Spree::DeliveryRateProvider::Estimate, nil]
    def estimate(package)
      return if integration.nil?
      return if package.order.ship_address.nil?

      rate = begin
        matching_rate(package)
      rescue StandardError => e
        Rails.error.report(e, context: { delivery_method_id: delivery_method.id }, source: 'spree_easypost.rating')
        nil
      end
      return if rate.nil?

      Spree::DeliveryRateProvider::Estimate.new(
        cost: rate.rate,
        carrier: rate.carrier,
        service_level: rate.service,
        estimated_delivery_date: rate.delivery_date,
        metadata: { 'easypost_rate_id' => rate.id, 'easypost_shipment_id' => rate.shipment_id }
      )
    end

    private

    def matching_rate(package)
      carrier = delivery_method.metadata['carrier']
      service = delivery_method.metadata['service']
      return if carrier.blank? || service.blank?

      easypost_shipment(package).rates.find do |rate|
        rate.carrier == carrier && rate.service == service
      end
    end

    # One shipment-create returns rates for every carrier and service, so all
    # delivery methods sharing this provider within a request reuse it.
    def easypost_shipment(package)
      cache_key = [:easypost_shipment, store.id, package.stock_location.id, package.order.id]
      Spree::Current.provider_cache[cache_key] ||= integration.client.shipment.create(
        from_address: address_params(package.stock_location),
        to_address: address_params(package.order.ship_address),
        parcel: parcel_params(package)
      )
    end

    def address_params(source)
      SpreeEasyPost.address_params(source)
    end

    def parcel_params(package)
      { weight: SpreeEasyPost.ounces(package.weight, store) }
    end
  end
end
