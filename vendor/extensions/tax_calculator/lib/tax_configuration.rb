class TaxConfiguration < Configuration

  preference :show_price_inc_vat, :boolean, :default => true
  
  validates_presence_of :name
  validates_uniqueness_of :name
end
