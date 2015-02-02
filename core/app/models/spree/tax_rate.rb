module Spree
  class DefaultTaxZoneValidator < ActiveModel::Validator
    def validate(record)
      if record.included_in_price
        record.errors.add(:included_in_price, Spree.t(:included_price_validation)) unless Zone.default_tax
      end
    end
  end
end

module Spree
  class TaxRate < Spree::Base
    acts_as_paranoid

    include Spree::CalculatedAdjustments
    include Spree::AdjustmentSource

    belongs_to :zone, class_name: "Spree::Zone", inverse_of: :tax_rates
    belongs_to :tax_category, class_name: "Spree::TaxCategory", inverse_of: :tax_rates

    validates :amount, presence: true, numericality: true
    validates :tax_category_id, presence: true
    validates_with DefaultTaxZoneValidator

    scope :by_zone, ->(zone) { where(zone_id: zone) }

    def self.potential_rates_for_zone(zone)
      select("spree_tax_rates.*, spree_zones.default_tax").
        joins(:zone).
        merge(Spree::Zone.potential_matching_zones(zone)).
        order("spree_zones.default_tax DESC")
    end

    # Gets the array of TaxRates appropriate for the specified order
    def self.match(order_tax_zone)
      return [] unless order_tax_zone

      potential_rates = potential_rates_for_zone(order_tax_zone)
      rates = potential_rates.includes(zone: { zone_members: :zoneable }).load.select do |rate|
        # Why "potentially"?
        # Go see the documentation for that method.
        rate.potentially_applicable?(order_tax_zone)
      end

      # Imagine with me this scenario:
      # You are living in Spain and you have a store which ships to France.
      # Spain is therefore your default tax rate.
      # When you ship to Spain, you want the Spanish rate to apply.
      # When you ship to France, you want the French rate to apply.
      #
      # Normally, Spree would notice that you have two potentially applicable
      # tax rates for one particular item.
      # When you ship to Spain, only the Spanish one will apply.
      # When you ship to France, you'll see a Spanish refund AND a French tax.
      # This little bit of code at the end stops the Spanish refund from appearing.
      #
      # For further discussion, see #4397 and #4327.
      rates.delete_if do |rate|
        rate.included_in_price? &&
        (rates - [rate]).map(&:tax_category).include?(rate.tax_category)
      end
    end

    # Pre-tax amounts must be stored so that we can calculate
    # correct rate amounts in the future. For example:
    # https://github.com/spree/spree/issues/4318#issuecomment-34723428
    def self.store_pre_tax_amount(item, rates)
      pre_tax_amount = case item
        when Spree::LineItem then item.discounted_amount
        when Spree::Shipment then item.discounted_cost
        end

      included_rates = rates.select(&:included_in_price)
      if included_rates.any?
        pre_tax_amount /= (1 + included_rates.map(&:amount).sum)
      end

      item.update_column(:pre_tax_amount, pre_tax_amount)
    end

    # This method is best described by the documentation on #potentially_applicable?
    def self.adjust(order, items)
      rates = match(order.tax_zone)
      tax_categories = rates.map(&:tax_category)
      relevant_items, non_relevant_items = items.partition { |item| tax_categories.include?(item.tax_category) }
      Spree::Adjustment.where(adjustable: relevant_items).tax.destroy_all # using destroy_all to ensure adjustment destroy callback fires.
      relevant_items.each do |item|
        relevant_rates = rates.select { |rate| rate.tax_category == item.tax_category }
        store_pre_tax_amount(item, relevant_rates)
        relevant_rates.each do |rate|
          rate.adjust(order, item)
        end
      end
      non_relevant_items.each do |item|
        if item.adjustments.tax.present?
          item.adjustments.tax.destroy_all # using destroy_all to ensure adjustment destroy callback fires.
          item.update_columns pre_tax_amount: 0
        end
      end
    end

    # Tax rates can *potentially* be applicable to an order.
    # We do not know if they are/aren't until we attempt to apply these rates to
    # the items contained within the Order itself.
    # For instance, if a rate passes the criteria outlined in this method,
    # but then has a tax category that doesn't match against any of the line items
    # inside of the order, then that tax rate will not be applicable to anything.
    # For instance:
    #
    # Zones:
    #   - Spain (default tax zone)
    #   - France
    #
    # Tax rates: (note: amounts below do not actually reflect real VAT rates)
    #   21% inclusive - "Clothing" - Spain
    #   18% inclusive - "Clothing" - France
    #   10% inclusive - "Food" - Spain
    #   8% inclusive - "Food" - France
    #   5% inclusive - "Hotels" - Spain
    #   2% inclusive - "Hotels" - France
    #
    # Order has:
    #   Line Item #1 - Tax Category: Clothing
    #   Line Item #2 - Tax Category: Food
    #
    # Tax rates that should be selected:
    #
    #  21% inclusive - "Clothing" - Spain
    #  10% inclusive - "Food" - Spain
    #
    # If the order's address changes to one in France, then the tax will be recalculated:
    #
    #  18% inclusive - "Clothing" - France
    #  8% inclusive - "Food" - France
    #
    # Note here that the "Hotels" tax rates will not be used at all.
    # This is because there are no items which have the tax category of "Hotels".
    #
    # Under no circumstances should negative adjustments be applied for the Spanish tax rates.
    #
    # Those rates should never come into play at all and only the French rates should apply.
    def potentially_applicable?(order_tax_zone)
      # If the rate's zone matches the order's tax zone, then it's applicable.
      self.zone == order_tax_zone ||
      # If the rate's zone *contains* the order's tax zone, then it's applicable.
      self.zone.contains?(order_tax_zone) ||
      # 1) The rate's zone is the default zone, then it's always applicable.
      (self.included_in_price? && self.zone.default_tax)
    end

    def adjust(order, item)
      included = included_in_price && default_zone_or_zone_match?(order)
      create_adjustment(order, item, included)
    end

    def compute_amount(item)
      refund = included_in_price && !default_zone_or_zone_match?(item.order)
      compute(item) * (refund ? -1 : 1)
    end

    private

    def default_zone_or_zone_match?(order)
      Zone.default_tax.try(:contains?, order.tax_zone) || order.tax_zone == zone
    end

    def label(adjustment_amount)
      label = ""
      label << Spree.t(:refund) << ' ' if adjustment_amount < 0
      label << (name.present? ? name : tax_category.name) + " "
      label << (show_rate_in_label? ? "#{amount * 100}%" : "")
      label << " (#{Spree.t(:included_in_price)})" if included_in_price?
      label
    end
  end
end
