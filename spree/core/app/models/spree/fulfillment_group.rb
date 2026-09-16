module Spree
  # One real parcel of a purchase, across however many orders it belongs to.
  #
  # A checkout that spans several sellers divides into one order per seller,
  # and a parcel holding more than one seller's goods divides with them: the
  # split clones the fulfillment onto each sibling and apportions the one
  # delivery charge the customer was quoted between the halves
  # (+Spree::Carts::SplitBySeller+). So "how many orders" and "how many
  # parcels" are different numbers, and anything telling a customer what to
  # expect has to answer the second — three orders shipping out of one
  # warehouse are still one box, and saying otherwise promises deliveries that
  # will never arrive.
  #
  # Ephemeral, never persisted: it is a reading of the fulfillments, and they
  # remain the record.
  class FulfillmentGroup
    include ActiveModel::Model
    include ActiveModel::Attributes

    attr_accessor :fulfillments

    # Collapses divided halves back into the parcels that actually ship.
    #
    # Halves of a divided parcel share their origin and their delivery method,
    # because the clone copies both. Genuinely separate parcels differ in at
    # least one: a seller shipping from their own warehouse differs in origin
    # even when quoted on a marketplace method the operator shares with them
    # (+DeliveryMethod#available_to_sellers+), and two parcels leaving one
    # warehouse differ in method. The pair is safe as an identity because the
    # packer builds one package per stock location per order, so it cannot
    # produce two same-origin same-method fulfillments on its own — only the
    # split can.
    #
    # @param fulfillments [Enumerable<Spree::Fulfillment>]
    # @return [Array<Spree::FulfillmentGroup>] in the order the fulfillments
    #   were given, so a caller that ordered them decides how the parcels read
    def self.build_from(fulfillments)
      fulfillments.group_by { |fulfillment| identity(fulfillment) }.
        map { |_identity, members| new(fulfillments: members) }
    end

    # @return [Array] origin and delivery method — see {.build_from}
    def self.identity(fulfillment)
      [fulfillment.stock_location_id, fulfillment.selected_delivery_rate&.delivery_method_id]
    end

    # @return [Spree::DeliveryMethod, nil]
    def delivery_method
      primary.delivery_method
    end

    # What the customer chose to be delivered by, named as they were shown it —
    # a provider rate carries its own label ("UPS Ground"), a calculated one
    # reads through to the method.
    #
    # @return [String, nil]
    def name
      primary.selected_delivery_rate&.name || delivery_method&.name
    end

    # @return [Spree::StockLocation, nil]
    def stock_location
      primary.stock_location
    end

    # What this parcel costs to deliver: the halves' apportioned shares added
    # back up, which is what the customer was quoted for it before the split
    # divided anything.
    #
    # @return [BigDecimal]
    def cost
      fulfillments.sum { |fulfillment| fulfillment.discounted_cost.to_d }
    end

    # @return [String, Spree::Money] the forwarder's placeholder while a
    #   freight rate is unpriced, money otherwise
    def display_cost(**options)
      return primary.display_cost(**options) if unpriced?

      Spree::Money.new(cost, { currency: primary.currency }.merge(options))
    end

    # @return [Boolean]
    def unpriced?
      fulfillments.any?(&:unpriced?)
    end

    # @return [Array<Spree::LineItem>] every line this parcel carries part of
    def line_items
      fulfillments.flat_map(&:line_items).uniq
    end

    # What the parcel carries, each line with the quantity *this* parcel holds.
    #
    # A line item can be packed from two warehouses, which puts it in two
    # parcels — printing the line's own quantity in both would show the
    # customer more goods than they bought, and charge for them twice.
    #
    # @return [Array<Spree::Fulfillment::ManifestItem>]
    def manifest
      fulfillments.flat_map(&:manifest).group_by(&:line_item).map do |line_item, items|
        Spree::Fulfillment::ManifestItem.new(line_item, line_item.variant, items.sum(&:quantity), nil)
      end
    end

    # Who is shipping it. More than one only where a marketplace's own
    # warehouse ships several sellers' goods in one box.
    #
    # @return [Array<Spree::Seller>]
    def sellers
      fulfillments.filter_map { |fulfillment| fulfillment.order&.seller }.uniq
    end

    # @return [Array<Spree::Order>]
    def orders
      fulfillments.filter_map(&:order).uniq
    end

    private

    # The half that answers for the parcel. Every half carries the same origin,
    # method and rate name — only the money was divided.
    def primary
      fulfillments.first
    end
  end
end
