class TaxRate < ActiveRecord::Base
  belongs_to :zone
  belongs_to :tax_category

  validates :amount, :presence => true, :numericality => true

  calculated_adjustments
  scope :by_zone, lambda { |zone| where("zone_id = ?", zone)}

  # Searches all possible TaxRates and returns the Zone which represents the most appropriate match (if any.)
  # To be considered for a match, the Zone must include the supplied address.  If multiple matches are
  # found, the Zone with the highest rate will be returned.  This method will return +nil+ if no match is found.
  def self.match(address)
    matching_rates = TaxRate.all.select { |rate| rate.zone.include? address }
    matching_rates.max { |a, b| a.amount <=> b.amount }
  end
end
