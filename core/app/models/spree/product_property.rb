module Spree
  class ProductProperty < ActiveRecord::Base
    belongs_to :product, :class_name => "Spree::Product"
    belongs_to :property, :class_name => "Spree::Property"

    validates :property, :presence => true
    validates_length_of :value, :maximum => 255

    attr_accessible :property_name, :value

    # virtual attributes for use with AJAX completion stuff
    def property_name
      property.name if property
    end

    def property_name=(name)
      self.property = Property.find_by_name(name) unless name.blank?
    end
  end
end
