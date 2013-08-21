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
        (rate.included_in_price && !order.tax_address.nil? && !rate.zone.contains?(order.tax_zone) && rate.zone.default_tax)
      end
    end

    def self.adjust(order, items)
      self.match(order).each do |rate|
        items.each { |item| rate.adjust(order, item) }
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
      if included_in_price
        if Zone.default_tax.contains? order.tax_zone
          create_adjustment order, item
        else
          create_adjustment order, item, 'refund'
        end
      else
        create_adjustment order, item
      end
    end

    # This method is used by Adjustment#update to recalculate the cost.
    def compute_amount(item)
      calculator.compute(item)
    end

    private
      def create_adjustment(order, item, type = 'normal')
        item.adjustments.tax.delete_all
        amount = compute_amount(item)
        return unless amount > 0

        if type == 'refund'
          amount = amount * -1
          label = Spree.t(:refund) + ' ' + create_label
        end

        self.adjustments.create!({
          :adjustable => item,
          :amount => amount,
          :order => order,
          :state => "closed",
          :label => label || create_label
        })
      end

      def create_label
        label = ""
        label << (name.present? ? name : tax_category.name) + " "
        label << (show_rate_in_label? ? "#{amount * 100}%" : "")
      end
  end
end
