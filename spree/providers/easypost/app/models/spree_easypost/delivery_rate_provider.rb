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

    # EasyPost quotes parcel carriers only.
    def self.fulfillment_types
      ['shipping']
    end

    # Static catalog for the admin service picker. EasyPost's live
    # carrier-account listing needs a production key, and the service names
    # are stable — so the gem ships the common set; a service missing here
    # still quotes fine (service rows are free-form, the catalog is a
    # convenience).
    def self.service_catalog(_integration)
      SpreeEasyPost::SERVICE_CATALOG
    end

    # A rating failure must never break checkout: any API error suppresses
    # this method (the customer still sees calculator-priced options) and is
    # reported for observability rather than raised into the rate refresh.
    #
    # @param package [Spree::Stock::Package]
    # @return [Array<Spree::DeliveryRateProvider::Estimate>]
    def estimates(package)
      return [] if integration.nil?
      return [] if package.order.ship_address.nil?

      rates = begin
        easypost_shipment(package).rates
      rescue StandardError => e
        Rails.error.report(e, context: { delivery_method_id: delivery_method.id }, source: 'spree_easypost.rating')
        []
      end

      rates.map do |rate|
        Spree::DeliveryRateProvider::Estimate.new(
          cost: rate.rate,
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
      SpreeEasyPost.parcel_params(package, store)
    end
  end
end
