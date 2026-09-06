module Spree
  module Stock
    class Package
      attr_reader :stock_location, :contents
      attr_accessor :delivery_rates
      # The cart or order this package is being quoted for. Every builder sets
      # it — a fulfillment, the allocator for a proposal — so the package takes
      # its currency, store and destination from the real record instead of
      # {#owner}'s fallback.
      attr_writer :owner

      def initialize(stock_location, contents = [])
        @stock_location = stock_location
        @contents = contents
        @delivery_rates = []
      end

      # Who this package is for.
      #
      # Prefers the owner it was built with. The walk to `inventory_unit.order`
      # is only a safety net for packages built by code that sets none, and it
      # answers badly in both directions: a cart's units carry no order_id, so
      # it returns nil and the package has no store or currency of its own,
      # while a unit carrying an order_id from elsewhere returns a stranger's
      # order — whose currency and ship address would stand in for the
      # customer's.
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
        @freight_summary = nil
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
        @freight_summary = nil
      end

      # Fix regression that removed package.order.
      # Find it dynamically through an inventory_unit.
      def order
        contents.detect { |item| !!item.try(:inventory_unit).try(:order) }.try(:inventory_unit).try(:order)
      end

      def item_total
        contents.sum(&:amount)
      end

      # Content weight plus the tare of the store's default package (the box
      # itself, plus filler). This is the single point every weight consumer
      # reads — calculators, rate providers, weight rules and the weight
      # splitter — so the tare applies everywhere without any of them knowing
      # about it.
      def weight
        contents.sum(&:weight) + tare
      end

      # The store's default package dimensions (the box this package ships
      # in), used verbatim by carrier rate providers for dimensional-weight
      # pricing. Item dimensions are deliberately not summed — items don't
      # stack into a box shape. Nil until the store records all three.
      #
      # @return [Hash{Symbol => Float}, nil]
      def dimensions
        default_package_type&.dimensions_in(store_dimensions_unit)
      end

      # How this package's contents roll up into freight logistics — cartons,
      # pallets, cubic meters, gross weight. Computed live; an order's summary
      # comes from the frozen copy on its selected delivery rate instead.
      #
      # @return [Spree::FreightSummary]
      # Memoized because quoting reads it repeatedly, and dropped whenever the
      # contents change — a stale volume would pick the wrong freight tier.
      def freight_summary
        @freight_summary ||= Spree::FreightSummary.build(contents)
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
        contents.first&.variant&.resolved_delivery_profile
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

      # Cubic meters of packed goods — carton volume where the contents
      # declare cartons, unit volume otherwise. Cartons stack, so unlike
      # +dimensions+ this genuinely sums.
      #
      # @return [BigDecimal]
      def volume
        freight_summary.total_volume
      end

      def dimension
        contents.sum(&:dimension)
      end

      private

      # The store's default box.
      #
      # @return [Spree::PackageType, nil]
      def default_package_type
        return @default_package_type if defined?(@default_package_type)

        @default_package_type = owner&.store&.default_package_type
      end

      # The box's own weight, converted into the unit the contents are
      # measured in. A merchant may record a carton in kilograms while the
      # store quotes in pounds, and adding those numbers together would
      # understate the tare by more than half.
      #
      # @return [BigDecimal]
      def tare
        package_type = default_package_type
        return 0 if package_type.nil?

        package_type.weight_in(owner&.store&.preferred_weight_unit || Spree::Measurement::DEFAULT_WEIGHT_UNIT)
      end

      # What a dimension means to this store, matching the fallback a
      # variant's own dimensions take.
      #
      # @return [String]
      def store_dimensions_unit
        Spree::Variant.store_dimensions_unit(owner&.store)
      end

      def variant_ids
        contents.map { |item| item.inventory_unit.variant_id }.compact.uniq
      end
    end
  end
end
