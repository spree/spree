module SpreeKlaviyo
  # One Klaviyo event, as a `POST /api/events` body, under Klaviyo's standard
  # ecommerce metric names and property names.
  #
  # Every event carries a unique_id taken from a Spree record or the Spree
  # event behind it, because Klaviyo keeps only the first event per profile,
  # metric and unique_id, and a retried job must not record one twice.
  class MetricEvent
    include ActiveModel::Model
    include ActiveModel::Attributes

    PLACED_ORDER = 'Placed Order'.freeze
    ORDERED_PRODUCT = 'Ordered Product'.freeze
    FULFILLED_ORDER = 'Fulfilled Order'.freeze
    CANCELED_ORDER = 'Canceled Order'.freeze
    RETURN_REFUNDED = 'Return Refunded'.freeze

    # What an item's properties read, loaded with the lines rather than one
    # query per line.
    ITEM_PRELOADS = {
      variant: [{ primary_media: { attachment_attachment: :blob } },
                { product: [:categories, { primary_media: { attachment_attachment: :blob } }] }]
    }.freeze

    attribute :metric, :string
    attribute :email, :string
    attribute :unique_id, :string
    attribute :time, :datetime
    attribute :currency, :string
    # BigDecimal until the body is built; nil for an event that is not revenue.
    attr_accessor :value, :properties

    class << self
      # One per purchase: the order's, or the group's for a split checkout,
      # whose child orders send none.
      #
      # @param purchase [Spree::Order, Spree::OrderGroup]
      # @param notify_customer [Boolean]
      def placed_order(purchase, notify_customer:)
        new(
          metric: PLACED_ORDER,
          email: purchase.email,
          unique_id: purchase.prefixed_id,
          time: purchase.is_a?(Spree::OrderGroup) ? purchase.cart&.completed_at : purchase.completed_at,
          currency: purchase.currency,
          value: purchase.total.to_d,
          properties: purchase_properties(purchase).merge(NotifyCustomer: notify_customer)
        )
      end

      # @param line_item [Spree::LineItem]
      def ordered_product(line_item)
        order = line_item.order

        new(
          metric: ORDERED_PRODUCT,
          email: order.email,
          unique_id: line_item.prefixed_id,
          time: order.completed_at,
          currency: line_item.currency,
          value: line_item.amount.to_d,
          properties: item_properties(line_item, line_item.quantity, order.store.storefront_url).merge(OrderId: order_id(order))
        )
      end

      # One per package, valued at that package's lines, because a shipping
      # email names one package's tracking.
      #
      # @param fulfillment [Spree::Fulfillment]
      # @param notify_customer [Boolean]
      def fulfilled_order(fulfillment, notify_customer:)
        order = fulfillment.order
        ActiveRecord::Associations::Preloader.new(
          records: [fulfillment], associations: { fulfillment_items: [:variant, { line_item: ITEM_PRELOADS }] }
        ).call
        lines = fulfillment.manifest.map { |item| [item.line_item, item.quantity] }
        storefront_url = order.store.storefront_url
        items = lines.map { |line_item, quantity| item_properties(line_item, quantity, storefront_url) }

        new(
          metric: FULFILLED_ORDER,
          email: order.email,
          unique_id: fulfillment.prefixed_id,
          time: fulfillment.fulfilled_at,
          currency: order.currency,
          value: lines.sum(BigDecimal(0)) { |line_item, quantity| line_item.price.to_d * quantity },
          properties: {
            OrderId: order_id(order),
            FulfillmentNumber: fulfillment.number,
            TrackingNumber: fulfillment.tracking,
            TrackingURL: fulfillment.tracking_url,
            ItemNames: items.pluck(:ProductName),
            Items: items,
            ShippingAddress: address_properties(fulfillment.address || order.ship_address),
            NotifyCustomer: notify_customer
          }
        )
      end

      # Shares the Placed Order's unique_id for an ordinary order, so Klaviyo
      # subtracts it from lifetime value.
      #
      # @param order [Spree::Order]
      # @param notify_customer [Boolean]
      def canceled_order(order, notify_customer:)
        new(
          metric: CANCELED_ORDER,
          email: order.email,
          unique_id: order.prefixed_id,
          time: order.canceled_at,
          currency: order.currency,
          value: order.total.to_d,
          properties: purchase_properties(order).merge(NotifyCustomer: notify_customer)
        )
      end

      # Not revenue: the refunded total is a property, so refunds never reduce
      # lifetime value. One per refund of a return, hence the Spree event's id.
      #
      # @param return_record [Spree::Return]
      # @param event_id [String] the `return.refunded` event's id
      # @param published_at [Time] when that event was published
      def return_refunded(return_record, event_id:, published_at:)
        order = return_record.order
        storefront_url = order.store.storefront_url
        items = return_record.return_line_items.includes(line_item: ITEM_PRELOADS).map do |return_line_item|
          item_properties(return_line_item.line_item, return_line_item.quantity, storefront_url)
        end

        new(
          metric: RETURN_REFUNDED,
          email: order.email,
          unique_id: event_id,
          time: published_at,
          currency: return_record.currency,
          properties: {
            ReturnNumber: return_record.number,
            OrderId: order_id(order),
            RefundedTotal: return_record.refunded_total.to_d,
            Currency: return_record.currency,
            ItemNames: items.pluck(:ProductName),
            Items: items
          }
        )
      end

      private

      # The number the customer was given: the group's for a split checkout.
      def order_id(order)
        order.order_group&.number || order.number
      end

      def purchase_properties(purchase)
        storefront_url = purchase.store.storefront_url
        items = purchase.line_items.includes(ITEM_PRELOADS).map do |line_item|
          item_properties(line_item, line_item.quantity, storefront_url)
        end
        codes = purchase.discounts.filter_map(&:code).uniq

        {
          OrderId: purchase.is_a?(Spree::OrderGroup) ? purchase.number : order_id(purchase),
          ItemNames: items.pluck(:ProductName),
          Categories: items.flat_map { |item| item[:Categories] }.uniq,
          Items: items,
          DiscountCode: codes.join(', ').presence,
          DiscountValue: purchase.discount_total.to_d.abs,
          Subtotal: purchase.item_total.to_d,
          ShippingTotal: purchase.delivery_total.to_d,
          TaxTotal: purchase.tax_total.to_d,
          Total: purchase.total.to_d,
          BillingAddress: address_properties(purchase.bill_address),
          ShippingAddress: address_properties(purchase.ship_address)
        }
      end

      def item_properties(line_item, quantity, storefront_url)
        product = line_item.product

        {
          ProductID: product&.prefixed_id,
          SKU: line_item.sku,
          ProductName: line_item.name,
          Quantity: quantity,
          ItemPrice: line_item.price.to_d,
          RowTotal: line_item.price.to_d * quantity,
          ProductURL: product && "#{storefront_url}/products/#{product.slug}",
          ImageURL: image_url(line_item.thumbnail),
          Categories: product ? product.categories.map(&:name) : []
        }
      end

      def image_url(media)
        image_renderer.spree_image_url(media, variant: :large)
      end

      def image_renderer
        @image_renderer ||= Object.new.extend(Spree::ImagesHelper)
      end

      def address_properties(address)
        return if address.nil?

        {
          FirstName: address.first_name,
          LastName: address.last_name,
          Company: address.company,
          Address1: address.address1,
          Address2: address.address2,
          City: address.city,
          Region: address.state_name_text,
          RegionCode: address.state_code,
          Country: address.country&.name,
          CountryCode: address.country_code,
          Zip: address.postal_code,
          Phone: address.phone
        }.compact_blank
      end
    end

    # @return [Hash]
    def to_body
      {
        data: {
          type: 'event',
          attributes: {
            metric: { data: { type: 'metric', attributes: { name: metric } } },
            profile: { data: { type: 'profile', attributes: { email: email } } },
            properties: json_amounts(properties || {}),
            time: time&.iso8601,
            unique_id: unique_id,
            value: value && json_amount(value),
            value_currency: value && currency
          }.compact
        }
      }
    end

    private

    # Every amount is rounded to the currency once, here, and sent as a JSON
    # number, which is what Klaviyo takes.
    def json_amounts(object)
      case object
      when Hash then object.transform_values { |nested| json_amounts(nested) }
      when Array then object.map { |nested| json_amounts(nested) }
      when BigDecimal then json_amount(object)
      else object
      end
    end

    def json_amount(amount)
      rounded = Spree::Money::Rounding.to_currency(amount, currency)
      Spree::Money::Rounding.precision(currency).zero? ? rounded.to_i : rounded.to_f
    end
  end
end
