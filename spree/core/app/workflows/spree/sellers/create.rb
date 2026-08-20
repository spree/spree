module Spree
  module Sellers
    # Creates a seller and gives them somewhere to keep stock.
    #
    # A workflow rather than plain CRUD because a seller is not usable without
    # a stock location: it is where their inventory lives and where customer
    # returns are sent, so provisioning it belongs to creating them rather than
    # being a step an operator can forget. The legacy multi-vendor gem reached
    # the same conclusion but did it in an `after_create` callback with a
    # fallback inside the reader, which put a write inside a read.
    class Create < Spree::Workflow
      hooks :validate, :after_create

      # @return [Spree::Seller]
      attr_reader :seller

      # @return [Spree::StockLocation] provisioned for the new seller
      attr_reader :stock_location

      # @param store [Spree::Store]
      # @param attributes [Hash] seller attributes
      def perform(store:, attributes: {})
        super

        step :build_seller
        run_hooks :validate

        ApplicationRecord.transaction do
          step :save_seller
          step :provision_stock_location
        end

        run_hooks :after_create
        seller.publish_event('seller.created')
        success(seller.reload)
      end

      private

      def build_seller
        @seller = store.sellers.new(attributes)
        @seller.status ||= Spree::Seller.default_status
      end

      def save_seller
        failure(seller, seller.errors) unless seller.save
      end

      # Named after the seller, since that is what an operator scanning every
      # location in the marketplace needs to see. `default` is per-owner, so
      # this is the default among *this seller's* locations and leaves the
      # operator's own alone.
      def provision_stock_location
        @stock_location = seller.stock_locations.new(
          store: seller.store,
          name: seller.name,
          default: true,
          active: true,
          country_code: seller.store.default_country_code
        )
        # A new seller has no catalog, so there is nothing to propagate — the
        # levels arrive with their products.
        @stock_location.propagate_all_variants = false

        failure(@stock_location, @stock_location.errors) unless @stock_location.save
      end
    end
  end
end
