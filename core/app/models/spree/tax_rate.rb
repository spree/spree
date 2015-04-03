module Spree
  class TaxRate < Spree::Base
    acts_as_paranoid

    include Spree::CalculatedAdjustments
    include Spree::AdjustmentSource

    belongs_to :zone, class_name: "Spree::Zone", inverse_of: :tax_rates
    belongs_to :tax_category, class_name: "Spree::TaxCategory", inverse_of: :tax_rates

    validates :amount, presence: true, numericality: true
    validates :tax_category_id, presence: true

    scope :by_zone, -> (zone) { where(zone_id: zone.id) }
    scope :potential_rates_for_zone,
          -> (zone) { where(zone_id: Spree::Zone.potential_matching_zones(zone).pluck(:id)) }
    scope :for_default_zone, -> { potential_rates_for_zone(Spree::Zone.default_tax) }
    scope :for_tax_category, -> (category) { where(tax_category_id: category.try(:id)) }
    scope :included_in_price, -> { where(included_in_price: true) }

    # Gets the array of TaxRates appropriate for the specified tax zone
    def self.match(order_tax_zone)
      return [] unless order_tax_zone
      potential_rates_for_zone(order_tax_zone)
    end

    # Deletes all tax adjustments, then applies all applicable rates to relevant items
    def self.adjust(order, items)
      rates = match(order.tax_zone)
      tax_categories = rates.map(&:tax_category)

      # using destroy_all to ensure adjustment destroy callback fires.
      Spree::Adjustment.where(adjustable: items).tax.destroy_all

      relevant_items = items.select { |item| tax_categories.include?(item.tax_category) }
      relevant_items.each do |item|
        relevant_rates = rates.select { |rate| rate.tax_category == item.tax_category }
        relevant_rates.each do |rate|
          rate.adjust(order, item)
        end
      end
    end

    def self.included_tax_amount_for(zone, category)
      return 0 unless zone
      potential_rates_for_zone(zone)
        .included_in_price
        .for_tax_category(category)
        .pluck(:amount)
        .sum
    end

    def adjust(order, item)
      create_adjustment(order, item, included_in_price)
    end

    def compute_amount(item)
      compute(item)
    end

    private

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
