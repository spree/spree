module SpreeEasyPost
  # Quotes a delivery method from EasyPost. Each method maps to one carrier
  # service (metadata: `carrier` + `service`, e.g. UPS/Ground) — "Ground" and
  # "Express" are two DeliveryMethods sharing this provider, and the shared
  # shipment call below means quoting both costs one API round-trip.
  class DeliveryRateProvider < Spree::DeliveryRateProvider::Base
    def self.integration_class
      'SpreeEasyPost::Integration'
    end

    # @param package [Spree::Stock::Package]
    # @return [Spree::DeliveryRateProvider::Estimate, nil]
    def estimate(package)
      return if integration.nil?
      return if package.order.ship_address.nil?

      rate = matching_rate(package)
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
      {
        street1: source.address1,
        street2: source.address2,
        city: source.city,
        state: source.respond_to?(:state_abbr) ? source.state_abbr : source.state&.abbr,
        zip: source.zipcode,
        country: source.country&.iso,
        phone: source.phone
      }.compact_blank
    end

    # EasyPost expects ounces; Spree stores weight in the store's unit.
    def parcel_params(package)
      { weight: weight_in_ounces(package.weight) }
    end

    OUNCES_PER_UNIT = {
      'imperial' => 16.0,   # pounds
      'metric' => 0.03527396 # grams
    }.freeze

    def weight_in_ounces(weight)
      unit_system = store&.preferred_unit_system.presence || 'imperial'
      (weight.to_f * OUNCES_PER_UNIT.fetch(unit_system.to_s, 16.0)).round(2)
    end
  end
end
