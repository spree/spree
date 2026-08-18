# frozen_string_literal: true

module Spree
  module Commissions
    # What a commission rule is asked about: one sale, and everything a rule
    # might want to know about it.
    #
    # Assembled once per line rather than let each rule reach into the record
    # itself, so a rule stays a predicate and the expensive parts — the
    # category walk especially — are resolved for the whole order up front.
    # Mirrors Spree::Pricing::Context, which serves price rules the same way.
    class Context
      attr_reader :line_item, :fulfillment, :seller, :order, :currency

      # @param seller [Spree::Seller] the seller being charged
      # @param order [Spree::Order]
      # @param line_item [Spree::LineItem, nil] the sale being commissioned…
      # @param fulfillment [Spree::Fulfillment, nil] …or its delivery
      # @param currency [String, nil] defaults to the order's
      # @param categories [Array<Spree::Category>, nil] the product's
      #   categories *with their ancestors*, resolved once for the order — a
      #   rate on a parent governs everything filed beneath it
      def initialize(seller:, order:, line_item: nil, fulfillment: nil, currency: nil, categories: nil)
        @seller = seller
        @order = order
        @line_item = line_item
        @fulfillment = fulfillment
        @currency = currency || order&.currency
        @categories = categories
      end

      # What is being commissioned — the item, or the delivery.
      #
      # @return [Spree::LineItem, Spree::Fulfillment, nil]
      def subject
        line_item || fulfillment
      end

      # @return [Spree::Product, nil] nil when commissioning a delivery
      def product
        line_item&.variant&.product
      end

      # The product's categories and every category above them. Empty when
      # commissioning a delivery, which belongs to no category.
      #
      # @return [Array<Spree::Category>]
      def categories
        return @categories if @categories

        @categories = product ? Spree::Commissions::ResolveRate.categories_for([product]).fetch(product.id, []) : []
      end

      # The money a rule about value compares against.
      #
      # Whether that is the tax-inclusive or tax-exclusive figure depends on
      # the rate being considered, which is why the rate is passed in: a band
      # and the fee it gates must weigh the same sale the same way, or two
      # bands meeting at 50 would straddle a number the operator never set.
      #
      # @param rate [Spree::CommissionRate, nil] nil weighs the sale as it
      #   stands, which is all a caller without a rate in hand can mean
      # @return [BigDecimal, nil]
      def commission_basis(rate = nil)
        return nil if subject.nil?

        Spree::Commissions::CalculateLine.base_for(rate, subject)
      end
    end
  end
end
