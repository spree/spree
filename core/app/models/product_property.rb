class ProductProperty < ActiveRecord::Base
  belongs_to :product
  belongs_to :property
  
  validates :property, :presence => true
  
  # virtual attributes for use with AJAX completion stuff
  def property_name
    property.name if property
  end
  
  def property_name=(name)    
    self.property = Property.find_by_name(name) unless name.blank?
  end  
end
