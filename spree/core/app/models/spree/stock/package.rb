module Spree
  module Stock
    class Package
      attr_reader :stock_location, :contents
      attr_accessor :delivery_rates
      # The cart or order this package is being quoted for. Set when a
      # fulfillment builds the package; nil for proposed packages the
      # coordinator builds before anything is persisted.
      attr_writer :owner

      def initialize(stock_location, contents = [])
        @stock_location = stock_location
        @contents = contents
        @delivery_rates = []
      end

      # Who this package is for.
      #
      # Prefers the owner the fulfillment supplied over walking to
      # `inventory_unit.order`: during checkout a fulfillment belongs to a
      # Cart, while its units can still carry an order_id from elsewhere, and
      # following that returns a stranger's order — whose ship address would
      # then stand in for the customer's.
      #
      # @return [Spree::Cart, Spree::Order, nil]
      def owner
        @owner || order
      end

      # @deprecated Use {#delivery_rates}; removed in 6.1.
      def shipping_rates
        Spree::Deprecation.warn('Spree::Stock::Package#shipping_rates is deprecated and will be removed in Spree 6.1. Use #delivery_rates instead.')
        delivery_rates
      end

      # @deprecated Use {#delivery_rates=}; removed in 6.1.
      def shipping_rates=(rates)
        Spree::Deprecation.warn('Spree::Stock::Package#shipping_rates= is deprecated and will be removed in Spree 6.1. Use #delivery_rates= instead.')
        self.delivery_rates = rates
      end

      def add(inventory_unit, state = :on_hand)
        # Remove find_item check as already taken care by prioritizer
        contents << ContentItem.new(inventory_unit, state)
      end

      def add_multiple(inventory_units, state = :on_hand)
        inventory_units.each { |inventory_unit| add(inventory_unit, state) }
      end

      def remove(inventory_unit)
        item = find_item(inventory_unit)
        remove_item(item) if item
      end

      def remove_item(item)
        @contents -= [item]
      end

      # Fix regression that removed package.order.
      # Find it dynamically through an inventory_unit.
      def order
        contents.detect { |item| !!item.try(:inventory_unit).try(:order) }.try(:inventory_unit).try(:order)
      end

      def item_total
        contents.sum(&:amount)
      end

      # Content weight plus the store's default package weight (packaging
      # tare). This is the single seam every weight consumer reads —
      # calculators, rate providers, weight rules and the weight splitter —
      # so the tare applies everywhere without any of them knowing about it.
      def weight
        contents_weight = contents.sum(&:weight)
        tare = owner&.store&.preferred_default_package_weight.to_f

        contents_weight + tare
      end

      # The store's default package dimensions (the box this package ships
      # in), used verbatim by carrier rate providers for dimensional-weight
      # pricing. Item dimensions are deliberately not summed — items don't
      # stack into a box shape. Nil until the store configures all three,
      # in the unit implied by the store's unit system (in/cm).
      #
      # @return [Hash{Symbol => Float}, nil]
      def dimensions
        store = owner&.store
        return if store.nil?

        length = store.preferred_default_package_length.to_f
        width = store.preferred_default_package_width.to_f
        height = store.preferred_default_package_height.to_f
        return if [length, width, height].any?(&:zero?)

        { length: length, width: width, height: height }
      end

      def on_hand
        contents.select(&:on_hand?)
      end

      def backordered
        contents.select(&:backordered?)
      end

      def find_item(inventory_unit, state = nil)
        contents.detect do |item|
          item.inventory_unit == inventory_unit &&
            (!state || item.state.to_s == state.to_s)
        end
      end

      def quantity(state = nil)
        matched_contents = state.nil? ? contents : contents.select { |c| c.state.to_s == state.to_s }
        matched_contents.sum(&:quantity)
      end

      def empty?
        quantity.zero?
      end

      def currency
        owner&.currency ||
          contents.filter_map { |item| item.try(:inventory_unit)&.line_item&.currency }.first ||
          Spree::Current.currency
      end

      # The delivery profile every item in this package belongs to.
      # Splitters keep packages profile-homogeneous, so the first item's
      # profile is the package's.
      #
      # @return [Spree::DeliveryProfile, nil]
      def delivery_profile
        contents.first&.variant&.delivery_profile
      end

      # Delivery methods eligible to serve this package: exactly the
      # package's profile's methods. Per-product exclusions are
      # DeliveryMethodRules::ExcludedProductsRule, enforced with the other
      # rules in the Estimator's method filter.
      #
      # @return [ActiveRecord::Relation<Spree::DeliveryMethod>]
      def eligible_delivery_methods
        profile = delivery_profile
        return Spree::DeliveryMethod.none if profile.nil?

        profile.delivery_methods
      end

      # @deprecated Use {#eligible_delivery_methods}; removed in 6.1.
      def shipping_methods
        Spree::Deprecation.warn('Spree::Stock::Package#shipping_methods is deprecated and will be removed in Spree 6.1. Use #eligible_delivery_methods instead.')
        eligible_delivery_methods.to_a
      end

      def inspect
        contents.map do |content_item|
          "#{content_item.variant.name} #{content_item.state}"
        end.join(' / ')
      end

      def to_fulfillment
        # At this point we should only have one content item per inventory unit
        # across the entire set of inventory units to be shipped, which has been
        # taken care of by the Prioritizer
        contents.each { |content_item| content_item.inventory_unit.status = content_item.state.to_s }

        Spree::Fulfillment.new(
          stock_location: stock_location,
          delivery_rates: delivery_rates,
          fulfillment_items: contents.map(&:inventory_unit)
        )
      end

      # @deprecated Use {#to_fulfillment}; removed in 6.1.
      def to_shipment
        Spree::Deprecation.warn('Spree::Stock::Package#to_shipment is deprecated and will be removed in Spree 6.1. Use #to_fulfillment instead.')
        to_fulfillment
      end

      def volume
        contents.sum(&:volume)
      end

      def dimension
        contents.sum(&:dimension)
      end

      private

      def variant_ids
        contents.map { |item| item.inventory_unit.variant_id }.compact.uniq
      end
    end
  end
end
