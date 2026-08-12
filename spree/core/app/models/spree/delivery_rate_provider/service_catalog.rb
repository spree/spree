module Spree
  module DeliveryRateProvider
    # The answer to "which carrier services can this store offer?", as the
    # admin service picker needs it: either the services themselves, or the
    # reason the provider could not list them.
    #
    # Providers fetch live where their API allows it. When it does not — an
    # unconnected integration, a credential tier that forbids the listing
    # endpoint, a carrier outage — they return {.unavailable} with the
    # vendor's own message, and the picker explains the situation instead of
    # showing a silently empty or invented list.
    class ServiceCatalog
      include ActiveModel::Model
      include ActiveModel::Attributes

      # @return [Array<Hash>] `[{ carrier:, service:, label: }]`
      attribute :services, default: -> { [] }
      # @return [String, nil] why the services could not be listed
      attribute :error_message, :string

      # A provider that lists no services at all — the merchant enters
      # carrier/service identifiers free-form and every quoted rate is
      # offered. Not an error state.
      #
      # @return [ServiceCatalog]
      def self.none
        new
      end

      # @param services [Array<Hash>] each `{ carrier:, service:, label: }`
      # @return [ServiceCatalog]
      def self.listing(services)
        new(services: Array(services))
      end

      # @param message [String] the vendor's message, shown to the merchant
      # @return [ServiceCatalog]
      def self.unavailable(message)
        new(error_message: message)
      end

      # @return [Boolean]
      def available?
        error_message.blank?
      end
    end
  end
end
