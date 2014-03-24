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
      rates = all.select do |rate|
        # Why "potentially"?
        # Go see the documentation for that method.
        rate.potentially_applicable?(order)
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

    # This method is best described by the documentation on #potentially_applicable?
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
    def potentially_applicable?(order)
      # If the rate's zone matches the order's tax zone, then it's applicable.
      self.zone == order.tax_zone ||
      # If the rate's zone *contains* the order's tax zone, then it's applicable.
      self.zone.contains?(order.tax_zone) ||
      # 1) The rate's zone is the default zone, then it's always applicable.
      (self.included_in_price? && self.zone.default_tax)
    end

    # Creates necessary tax adjustments for the order.
    def adjust(order, item)
      amount = compute_amount(item)
      return if amount == 0

      included = included_in_price && default_zone_or_zone_match?(item)

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
        if default_zone_or_zone_match?(item)
          calculator.compute(item)
        else
          # In this case, it's a refund.
          calculator.compute(item) * - 1
        end
      else
        calculator.compute(item)
      end
    end

    def default_zone_or_zone_match?(item)
      Zone.default_tax.contains?(item.order.tax_zone) ||
      item.order.tax_zone == self.zone
    end

    private

      def create_label
        label = ""
        label << (name.present? ? name : tax_category.name) + " "
        label << (show_rate_in_label? ? "#{amount * 100}%" : "")
      end
  end
end
