class TaxRate < ActiveRecord::Base
  belongs_to :zone
  belongs_to :tax_category

  validates :amount, :presence => true, :numericality => true

  calculated_adjustments
  scope :by_zone, lambda { |zone| where("zone_id = ?", zone)}

  def self.match

  end
end
