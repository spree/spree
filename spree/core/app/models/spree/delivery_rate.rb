module Spree
  class DeliveryRate < Spree.base_class
    has_prefix_id :dr

    # Carrier payload from the rate provider (quote ids, service codes) —
    # a plain single column per the house rule for new columns, not the
    # legacy public/private Metadata pair.
    serialize :metadata, coder: Spree::Metadata::HashSerializer

    belongs_to :fulfillment, class_name: 'Spree::Fulfillment'
    belongs_to :tax_rate, -> { with_deleted }, class_name: 'Spree::TaxRate', optional: true
    belongs_to :delivery_method, -> { with_deleted }, class_name: 'Spree::DeliveryMethod', inverse_of: :delivery_rates
    # Legacy names — removed in 6.1.
    belongs_to :shipment, class_name: 'Spree::Fulfillment', foreign_key: :fulfillment_id, optional: true, deprecated: true
    belongs_to :shipping_method, -> { with_deleted }, class_name: 'Spree::DeliveryMethod', foreign_key: :delivery_method_id, optional: true, deprecated: true
    alias_attribute :shipment_id, :fulfillment_id
    alias_attribute :shipping_method_id, :delivery_method_id

    extend Spree::DisplayMoney

    money_methods :base_price, :final_price, :tax_amount, :additional_tax_total, :included_tax_total, :tax_total

    delegate :order, :currency, :with_free_shipping_promotion?, to: :fulfillment
    delegate :code, to: :delivery_method, prefix: true

    # Provider-priced rates carry their own display name ("UPS Ground", or a
    # merchant label override) set by the Estimator; calculator rates store
    # nil and read as the delivery method's name, preserving the historic
    # delegate behavior.
    #
    # @return [String]
    def name
      self[:name].presence || delivery_method.name
    end

    def display_price
      return quoted_after_review if unpriced?

      price = display_base_price.to_s

      return price if tax_rate.nil? || tax_amount.zero? || !tax_rate.show_rate_in_label

      Spree.t(
        tax_rate.included_in_price? ? :including_tax : :excluding_tax,
        scope: 'shipping_rates.display_price',
        price: price,
        tax_amount: display_tax_amount,
        tax_rate_name: tax_rate.name
      )
    end
    alias display_cost display_price
    alias_attribute :base_price, :cost

    # Returns true if the shipping rate is free.
    #
    # An unpriced rate is never free — its cost is zero because nobody has
    # quoted it yet, and saying "free shipping" over a container of goods
    # would be a promise the merchant cannot keep.
    #
    # @return [Boolean]
    def free?
      !unpriced? && final_price.zero?
    end

    # The logistics the freight provider computed when it quoted this rate —
    # cartons, pallets, cubic meters, gross weight. Frozen at estimate time
    # and never re-derived, so an order keeps reporting what it actually
    # shipped as.
    #
    # @return [Spree::FreightSummary, nil]
    def freight_summary
      @freight_summary ||= Spree::FreightSummary.from_metadata(metadata&.dig('freight_summary'))
    end

    # Returns the tax amount for the shipping rate, computed directly from
    # the rate configuration (rates display estimated tax before a
    # fulfillment exists, so this never reads TaxLine rows).
    #
    # @return [BigDecimal]
    def tax_amount
      @tax_amount ||= if tax_rate.nil?
                        BigDecimal(0)
                      elsif tax_rate.included_in_price?
                        (cost / (1 + tax_rate.amount) * tax_rate.amount).round(2)
                      else
                        (cost * tax_rate.amount).round(2)
                      end
    end

    # Returns the additional tax total for the shipping rate
    #
    # @return [BigDecimal]
    def additional_tax_total
      tax_rate&.included_in_price? ? BigDecimal(0) : tax_amount
    end

    # Returns the included tax total for the shipping rate
    #
    # @return [BigDecimal]
    def included_tax_total
      tax_rate&.included_in_price? ? tax_amount : BigDecimal(0)
    end

    alias tax_total tax_amount
    alias display_tax_total display_tax_amount

    # returns base price - any available discounts for this Shipment
    # useful when you want to present a list of available shipping rates
    def final_price
      if with_free_shipping_promotion? || cost < -discount_amount
        BigDecimal(0)
      else
        cost + discount_amount
      end
    end
    alias total final_price

    # Every money display on an unpriced rate says the same thing. A
    # storefront that renders the total rather than the cost would otherwise
    # put "$0.00" — free freight — in front of a buyer whose shipment has not
    # been quoted yet.
    #
    # Keeps the generated method's shape: the same keyword options, and a
    # Spree::Money on every priced path, so callers doing money arithmetic on
    # the total are unaffected.
    #
    # @return [String, Spree::Money]
    def display_final_price(**options)
      return quoted_after_review if unpriced?

      Spree::Money.new(final_price, { currency: currency }.merge(options))
    end
    alias display_total display_final_price

    # Returns the delivery range for the shipping method
    #
    # @return [String]
    def delivery_range
      return unless delivery_method.delivery_range

      delivery_method.delivery_range
    end

    # Returns the display delivery range for the shipping method
    #
    # @return [String]
    def display_delivery_range
      return unless delivery_range

      Spree.t(:display_delivery_range, delivery_range: delivery_range)
    end

    private

    # What every money display on this rate reads instead of an amount.
    def quoted_after_review
      Spree.t('delivery_rates.quoted_after_review')
    end

    def discount_amount
      fulfillment.discounts.promotion.sum(:amount)
    end
  end
end
