module Spree
  # What a cart or a package looks like to a freight forwarder: how many
  # units, how many cartons those fill, how many pallets those stack onto,
  # the cubic meters they occupy and what the whole thing weighs.
  #
  # These are the numbers a wholesale shipment is quoted and tiered on, and
  # they are not derivable from the retail shipping data — a case of 48 bottles
  # is one carton, not 48 parcels. A variant declares its carton
  # (docs/plans/6.0-b2b-wholesale-shipping.md) and the rollup follows the
  # chain Unit -> Carton -> Pallet -> CBM / weight.
  #
  # Lines whose variant declares no carton fall back to unit volume and
  # weight and mark the summary {#complete?} false, so the numbers stay
  # useful while saying plainly that some of the catalog is unmeasured.
  #
  # Carts compute this live; a completed order reads the copy frozen onto its
  # selected delivery rate, and never re-derives it from the live catalog.
  class FreightSummary
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :lines, default: -> { [] }

    class << self
      # Rolls up stock package contents.
      #
      # @param contents [Array<Spree::Stock::ContentItem>]
      # @return [Spree::FreightSummary]
      def build(contents)
        from_pairs(Array(contents).filter_map do |item|
          variant = item.variant
          [variant, item.quantity] if variant
        end)
      end

      # Rolls up a cart or an order directly, for surfaces that have no stock
      # package to hand — a cart summary shown before checkout picks a rate.
      #
      # @param purchase [Spree::Cart, Spree::Order]
      # @return [Spree::FreightSummary]
      def for_purchase(purchase)
        from_pairs(purchase.line_items.map { |line_item| [line_item.variant, line_item.quantity] })
      end

      # Rebuilds a summary from its serialized form — the frozen copy carried
      # in a delivery rate's metadata.
      #
      # @param payload [Hash, nil]
      # @return [Spree::FreightSummary, nil]
      def from_metadata(payload)
        return if payload.blank?

        payload = payload.with_indifferent_access
        lines = Array(payload[:lines]).map { |line| Spree::FreightSummary::Line.new(line.symbolize_keys) }
        new(lines: lines)
      end

      private

      def from_pairs(pairs)
        lines = pairs.filter_map do |variant, quantity|
          Spree::FreightSummary::Line.build(variant, quantity) if variant && quantity.to_i.positive?
        end

        new(lines: lines)
      end
    end

    # @return [Integer]
    def total_units
      sum_of(:units).to_i
    end

    # @return [Integer]
    def total_cartons
      sum_of(:cartons).to_i
    end

    # Pallets are only meaningful when every carton-bearing line says how it
    # stacks; one silent line would understate the load.
    #
    # @return [Integer, nil]
    def total_pallets
      carton_lines = lines.select(&:cartons?)
      return if carton_lines.empty? || carton_lines.any? { |line| line.pallets.nil? }

      carton_lines.sum(&:pallets)
    end

    # @return [BigDecimal] cubic meters
    def total_volume
      sum_of(:volume)
    end

    # @return [BigDecimal] kilograms
    def total_weight
      sum_of(:weight)
    end

    # True when every line was measured from its carton. False means some of
    # the figures above came from unit dimensions instead, which under-reports
    # the space packaging takes.
    #
    # @return [Boolean]
    def complete?
      lines.any? && lines.all?(&:complete?)
    end

    # True when there is nothing here worth reporting as freight — no lines,
    # or lines that measured to nothing because the catalog records no
    # dimensions. A retail cart of unmeasured goods has no freight summary
    # rather than one full of zeros, which would read as a shipment that
    # takes up no space.
    #
    # @return [Boolean]
    def empty?
      lines.empty? || (total_volume.zero? && total_weight.zero? && total_cartons.zero?)
    end

    # The serialized form frozen onto a delivery rate at completion.
    #
    # @return [Hash]
    def as_json(*)
      {
        'total_units' => total_units,
        'total_cartons' => total_cartons,
        'total_pallets' => total_pallets,
        'total_volume' => decimal_string(total_volume),
        'total_weight' => decimal_string(total_weight),
        'complete' => complete?,
        'lines' => lines.map(&:as_json)
      }
    end

    private

    # Plain decimal notation. BigDecimal's default renders 0.06 as "0.6e-1",
    # which is what a client would print beside "CBM".
    def decimal_string(value)
      BigDecimal(value.to_s).to_s('F')
    end

    def sum_of(attribute)
      lines.sum { |line| line.public_send(attribute) || 0 }
    end
  end
end
