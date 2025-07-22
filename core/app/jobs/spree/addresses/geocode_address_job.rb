module Spree
  module Addresses
    class GeocodeAddressError < StandardError; end

    class GeocodeAddressJob < BaseJob
      queue_as Spree.queues.addresses

      def perform(address_id)
        address = Spree::Address.find(address_id)

        coordinates = Geocoder.coordinates(
          address.geocoder_address,
          country: address.country_iso3
        )

        if coordinates.present?
          address.update_columns(latitude: coordinates[0], longitude: coordinates[1], updated_at: Time.current)
        else
          # Unfortunately there is no way to get the error message from Geocoder,
          # but the request is fully displayed in the server logs
          Rails.error.report(
            GeocodeAddressError.new("Cannot geocode address ID: #{address.id}"),
            handled: false,
            context: { address_id: address_id },
            source: 'spree.core'
          )
        end
      end
    end
  end
end
