module Spree
  class TaxRate < ActiveRecord::Base
    belongs_to :zone
    belongs_to :tax_category

    validates :amount, :presence => true, :numericality => true
    validates :tax_category_id, :presence => true

    calculated_adjustments :default => Calculator::SalesTax
    scope :by_zone, lambda { |zone| where(:zone_id => zone) }

    # Searches all possible TaxRates and returns the Zone which represents the most appropriate match (if any.)
    # To be considered for a match, the Zone must include the supplied address.  If multiple matches are
    # found, the Zone with the highest rate will be returned.  This method will return +nil+ if no match is found.
    def self.match(address)
      all.select { |rate| rate.zone.include? address }
    end

    # For Vat the default rate is the rate that is configured for the default category
    # It is needed for every price calculation (as all customer facing prices include vat )
    # The function returns the actual amount, which may be 0 in case of wrong setup, but is never nil
    def self.default
      category = TaxCategory.includes(:tax_rates).where(:is_default => true).first
      return 0 unless category

      category.effective_amount || 0
    end
  end
end
