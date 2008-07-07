class TaxRate < ActiveRecord::Base
  belongs_to :zone
  belongs_to :tax_category
  validates_numericality_of :rate
  validates_presence_of :rate
  named_scope :by_zone, lambda { |zone| { :conditions => ["zone_id = ?", zone] } }
  
  enumerable_constant :tax_type, :constants => [:sales_tax, :vat]
end
