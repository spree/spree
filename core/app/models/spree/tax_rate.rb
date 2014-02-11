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
  class TaxRate < ActiveRecord::Base
    acts_as_paranoid
    include Spree::Core::CalculatedAdjustments
    belongs_to :zone, class_name: "Spree::Zone"
    belongs_to :tax_category, class_name: "Spree::TaxCategory"

    has_many :adjustments, as: :source, dependent: :destroy

    validates :amount, presence: true, numericality: true
    validates :tax_category_id, presence: true
    validates_with DefaultTaxZoneValidator

    scope :by_zone, ->(zone) { where(zone_id: zone) }

    # Gets the array of TaxRates appropriate for the specified order
    def self.match(order)
      return [] unless order.tax_zone
      all.select do |rate|
        (!rate.included_in_price && (rate.zone == order.tax_zone || rate.zone.contains?(order.tax_zone) || (order.tax_address.nil? && rate.zone.default_tax))) ||
        rate.included_in_price
      end
    end

    # Pre-tax amounts must be stored so that we can calculate 
    # correct rate amounts in the future. For example:
    # https://github.com/spree/spree/issues/4318#issuecomment-34723428
    def self.store_pre_tax_amount(item, rates)
      if rates.any? { |r| r.included_in_price }
        case item
        when Spree::LineItem
          item_amount = item.discounted_amount
        when Spree::Shipment
          item_amount = item.discounted_cost
        end
        pre_tax_amount = item_amount / (1 + rates.map(&:amount).sum)
        item.update_column(:pre_tax_amount, pre_tax_amount)
      end
    end

    def self.adjust(order, items)
      rates = self.match(order)
      tax_categories = rates.map(&:tax_category)
      relevant_items = items.select { |item| tax_categories.include?(item.tax_category) }
      relevant_items.each do |item|
        item.adjustments.tax.delete_all
        relevant_rates = rates.select { |rate| rate.tax_category == item.tax_category }
        store_pre_tax_amount(item, relevant_rates)
        relevant_rates.each do |rate|
          rate.adjust(order, item)
        end
      end
    end

    # For Vat the default rate is the rate that is configured for the default category
    # It is needed for every price calculation (as all customer facing prices include vat )
    # The function returns the actual amount, which may be 0 in case of wrong setup, but is never nil
    def self.default
      category = TaxCategory.includes(:tax_rates).where(is_default: true).first
      return 0 unless category

      address ||= Address.new(country_id: Spree::Config[:default_country_id])
      rate = category.tax_rates.detect { |rate| rate.zone.include? address }.try(:amount)

      rate || 0
    end

    # Creates necessary tax adjustments for the order.
    def adjust(order, item)
      amount = calculator.compute(item)
      return if amount == 0

      included = included_in_price &&
                 Zone.default_tax.contains?(item.order.tax_zone)

      if amount < 0
        label = Spree.t(:refund) + ' ' + create_label
      end

      self.adjustments.create!({
        :adjustable => item,
        :amount => amount,
        :order => order,
        :label => label || create_label,
        :included => included
      })
    end

    # This method is used by Adjustment#update to recalculate the cost.
    def compute_amount(item)
      if included_in_price
        if Zone.default_tax.contains? item.order.tax_zone
          calculator.compute(item)
        else
          # In this case, it's a refund.
          calculator.compute(item) * - 1
        end
      else
        calculator.compute(item)
      end
    end

    private

      def create_label
        label = ""
        label << (name.present? ? name : tax_category.name) + " "
        label << (show_rate_in_label? ? "#{amount * 100}%" : "")
      end
  end
end
