module SpreeEasyPost
  # Quotes a delivery method from EasyPost. One method is the carrier
  # connection: every service EasyPost returns for the address becomes its
  # own rate ("UPS Ground", "USPS Priority", ...), and the method's service
  # rows narrow, rename or mark up individual services. Methods sharing this
  # provider within a request reuse one shipment-create API call.
  class DeliveryRateProvider < Spree::DeliveryRateProvider::Base
    def self.integration_class
      'SpreeEasyPost::Integration'
    end

    def self.provider_name
      SpreeEasyPost::PROVIDER_NAME
    end

    # EasyPost quotes real parcel shipments, so it only prices methods that
    # ship to an address.
    def self.requires_address?
      true
    end

    # Domestic destination + nominal parcel for the service-listing probe
    # quote; never charged, nothing to clean up.
    PROBE_DESTINATION = {
      street1: '179 N Harbor Dr',
      city: 'Redondo Beach',
      state: 'CA',
      zip: '90277',
      country: 'US',
      name: 'Service catalog probe'
    }.freeze
    PROBE_OUNCES = 16

    # The carrier services this account can actually sell.
    #
    # Read from a throwaway quote rather than the carrier-accounts endpoint:
    # the latter is production-only (a test key is rejected outright), while
    # a quote works on both key tiers and reports carrier names exactly as
    # they arrive on real rates — which is what service rows must match.
    # Costs one API call, made only when an admin opens the picker.
    def self.service_catalog(integration)
      return Spree::DeliveryRateProvider::ServiceCatalog.none if integration.nil?

      shipment = integration.client.shipment.create(
        from_address: SpreeEasyPost::Integration::VERIFICATION_ADDRESS,
        to_address: PROBE_DESTINATION,
        parcel: { weight: PROBE_OUNCES }
      )
      Spree::DeliveryRateProvider::ServiceCatalog.listing(services_from(shipment.rates))
    rescue StandardError => e
      Spree::DeliveryRateProvider::ServiceCatalog.unavailable(e.message)
    end

    # One entry per (carrier, service) the probe quoted, deduplicated and
    # ordered for a stable picker.
    def self.services_from(rates)
      rates.map { |rate| [rate.carrier, rate.service] }.uniq.sort.map do |carrier, service|
        { carrier: carrier, service: service, label: "#{carrier} #{service.to_s.titleize}" }
      end
    end
    private_class_method :services_from

    # A rating failure must never break checkout: any API error suppresses
    # this method (the customer still sees calculator-priced options) and is
    # reported for observability rather than raised into the rate refresh.
    #
    # @param package [Spree::Stock::Package]
    # @return [Array<Spree::DeliveryRateProvider::Estimate>]
    def estimates(package)
      return [] if integration.nil?
      return [] if package.owner&.ship_address.nil?

      rates = begin
        easypost_shipment(package).rates
      rescue StandardError => e
        Rails.error.report(e, context: { delivery_method_id: delivery_method.id }, source: 'spree_easypost.rating')
        []
      end

      rates.map do |rate|
        Spree::DeliveryRateProvider::Estimate.new(
          cost: rate.rate,
          currency: rate.currency,
          carrier: rate.carrier,
          service_level: rate.service,
          estimated_delivery_date: rate.delivery_date,
          metadata: { 'easypost_rate_id' => rate.id, 'easypost_shipment_id' => rate.shipment_id }
        )
      end
    end

    private

    # One shipment-create returns rates for every carrier and service, so all
    # delivery methods sharing this provider within a request reuse it.
    def easypost_shipment(package)
      cache_key = [:easypost_shipment, store.id, package.stock_location.id, package.owner.id]
      Spree::Current.provider_cache[cache_key] ||= integration.client.shipment.create(
        from_address: address_params(package.stock_location),
        to_address: address_params(package.owner.ship_address),
        parcel: parcel_params(package)
      )
    end

    def address_params(source)
      SpreeEasyPost.address_params(source)
    end

    def parcel_params(package)
      SpreeEasyPost.parcel_params(package, store)
    end
  end
end
