class PropertyValue < ActiveRecord::Base
  belongs_to :product
  belongs_to :property
  
  named_scope :tax_category, :include => :property, :conditions => ["properties.name = ?", "tax_category"]
end
