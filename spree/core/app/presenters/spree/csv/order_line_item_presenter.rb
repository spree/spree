module Spree
  module CSV
    class OrderLineItemPresenter
      HEADERS = [
        'Number',
        'Email',
        'Status',
        'Currency',
        'Subtotal',
        'Shipping',
        'Taxes',
        'Taxes included',
        'Discount Used',
        'Free Shipping',
        'Discount',
        'Discount Code',
        'Store Credit amount',
        'Total',
        'Shipping method',
        'Total weight',
        'Payment Type Used',
        'Product ID',
        'Item Quantity',
        'Item SKU',
        'Item Name',
        'Item Price',
        'Item Total Discount',
        'Item Total Price',
        'Item requires shipping',
        'Item taxbale',
        'Item Seller',
        'Category lvl0',
        'Category lvl1',
        'Category lvl2',
        'Category lvl3',
        'Category lvl4',
        'Billing Name',
        'Billing Address 1',
        'Billing Address 2',
        'Billing Company',
        'Billing City',
        'Billing Zip',
        'Billing State',
        'Billing Country',
        'Billing Phone',
        'Shipping Name',
        'Shipping Address 1',
        'Shipping Address 2',
        'Shipping Company',
        'Shipping City',
        'Shipping Zip',
        'Shipping State',
        'Shipping Country',
        'Shipping Phone',
        'Placed at',
        'Shipped at',
        'Cancelled at',
        'Cancelled by',
        'Notes'
      ].freeze

      # Columns a caller may leave out, and the headers naming them.
      #
      # Filtering both the header list and the row through the same names is
      # what keeps them aligned: dropping a cell by hand would silently shift
      # every value after it into the wrong column.
      #
      # @param order [Spree::Order]
      # @param line_item [Spree::LineItem]
      # @param index [Integer] position within the order's line items; only
      #   the first row carries the order-level values
      # @param custom_fields [Array]
      # @param omit_headers [Array<String>] headers to leave out of this row
      def initialize(order, line_item, index, custom_fields = [], omit_headers: [])
        @order = order
        @line_item = line_item
        @index = index
        @custom_fields = custom_fields
        @omit_headers = Array(omit_headers)
      end

      attr_accessor :order, :line_item, :index, :custom_fields
      attr_reader :omit_headers

      # The headers this presenter emits, minus the omitted ones.
      #
      # @param omit_headers [Array<String>]
      # @return [Array<String>]
      def self.headers(omit_headers: [])
        HEADERS - Array(omit_headers)
      end

      def call
        csv = [
          order.number,
          index.zero? ? order.email : nil,
          index.zero? ? order.status : nil,
          index.zero? ? order.currency : nil,
          index.zero? ? order.item_total.to_f : nil,
          index.zero? ? order.shipment_total.to_f : nil,
          index.zero? ? order.tax_total.to_f : nil,
          index.zero? ? order.included_tax_total.positive? : nil,
          index.zero? ? (order.discount_total.negative? || line_item.discount_total.negative?) : nil,
          index.zero? ? order.has_free_shipping? : nil,
          index.zero? ? order.discount_total.abs : nil,
          index.zero? ? order.promo_code : nil,
          index.zero? ? order.payments.store_credits.sum(:amount).abs : nil,
          index.zero? ? order.total.to_f : nil,
          index.zero? ? order.delivery_method&.name : nil,
          index.zero? ? order.total_weight.to_f : nil,
          index.zero? ? order.payments.valid&.first&.display_source_name : nil,
          line_item.product_id,
          line_item.quantity,
          line_item.sku,
          line_item.name,
          line_item.price,
          line_item.discount_total.abs,
          line_item.total,
          !line_item.variant.digital?,
          line_item.product.tax_category_id.present?,
          line_item.product.try(:seller_name),
          taxon_dict(line_item.product.primary_category)[0],
          taxon_dict(line_item.product.primary_category)[1],
          taxon_dict(line_item.product.primary_category)[2],
          taxon_dict(line_item.product.primary_category)[3],
          taxon_dict(line_item.product.primary_category)[4],
          index.zero? ? order.bill_address&.full_name : nil,
          index.zero? ? order.bill_address&.address1 : nil,
          index.zero? ? order.bill_address&.address2 : nil,
          index.zero? ? order.bill_address&.company : nil,
          index.zero? ? order.bill_address&.city : nil,
          index.zero? ? order.bill_address&.zipcode : nil,
          index.zero? ? order.bill_address&.state_name : nil,
          index.zero? ? order.bill_address&.country&.name : nil,
          index.zero? ? order.bill_address&.phone : nil,
          index.zero? ? order.ship_address&.full_name : nil,
          index.zero? ? order.ship_address&.address1 : nil,
          index.zero? ? order.ship_address&.address2 : nil,
          index.zero? ? order.ship_address&.company : nil,
          index.zero? ? order.ship_address&.city : nil,
          index.zero? ? order.ship_address&.zipcode : nil,
          index.zero? ? order.ship_address&.state_name : nil,
          index.zero? ? order.ship_address&.country&.name : nil,
          index.zero? ? order.ship_address&.phone : nil,
          index.zero? ? format_date(order.completed_at) : nil,
          format_date(line_item.order.fulfillments.first&.fulfilled_at),
          index.zero? ? format_date(order.canceled_at) : nil,
          index.zero? ? order.canceler&.email : nil,
          index.zero? ? order.customer_note : nil
        ]

        csv = reject_omitted(csv)

        if index.zero?
          csv += custom_fields
        end

        csv
      end

      private

      # Drops the cells whose headers were omitted, matching each value to its
      # header by position so the row and the header list stay aligned.
      def reject_omitted(csv)
        return csv if omit_headers.empty?

        csv.reject.with_index { |_value, position| omit_headers.include?(HEADERS[position]) }
      end

      def taxon_dict(taxon)
        return [] if taxon.blank?

        taxon.pretty_name.to_s.split('->').map(&:strip)
      end

      def format_date(date)
        return nil if date.blank?

        date.in_time_zone(order.store.preferred_timezone).strftime('%Y-%m-%d %H:%M:%S')
      end
    end
  end
end
