module Spree
  # Manage (recalculate) item (LineItem or Shipment) adjustments
  class ItemAdjustments
    include ActiveSupport::Callbacks
    define_callbacks :promo_adjustments, :tax_adjustments
    attr_reader :item

    delegate :adjustments, :order, to: :item

    def initialize(item)
      @item = item

      # Don't attempt to reload the item from the DB if it's not there
      @item.reload if @item.instance_of?(Shipment) && @item.persisted?
      Adjustable::PromotionAccumulator.add_to(item)
    end

    def update
      update_adjustments if item.persisted?
      item
    end

    # TODO this should be probably the place to calculate proper item taxes
    # values after promotions are applied
    def update_adjustments
      # Promotion adjustments must be applied first, then tax adjustments.
      # This fits the criteria for VAT tax as outlined here:
      # http://www.hmrc.gov.uk/vat/managing/charging/discounts-etc.htm#1
      #
      # It also fits the criteria for sales tax as outlined here:
      # http://www.boe.ca.gov/formspubs/pub113/
      #
      # Tax adjustments come in not one but *two* exciting flavours:
      # Included & additional

      # Included tax adjustments are those which are included in the price.
      # These ones should not affect the eventual total price.
      #
      # Additional tax adjustments are the opposite, affecting the final total.
      promo_total = 0
      run_callbacks :promo_adjustments do
        adjustments.promotion.reload.each { |a| a.update!(item) }
        promo_total = Adjustable::PromotionSelector.select!(item)
      end

      included_tax_total = 0
      additional_tax_total = 0
      run_callbacks :tax_adjustments do
        tax = (item.respond_to?(:all_adjustments) ? item.all_adjustments : item.adjustments).tax
        included_tax_total = tax.included.reload.map(&:update!).compact.sum
        additional_tax_total = tax.additional.reload.map(&:update!).compact.sum
      end

      item.update_columns(
        :promo_total => promo_total,
        :included_tax_total => included_tax_total,
        :additional_tax_total => additional_tax_total,
        :adjustment_total => promo_total + additional_tax_total,
        :updated_at => Time.now,
      )
    end

  end
end
