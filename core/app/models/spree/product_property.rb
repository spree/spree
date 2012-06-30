module Spree
  class ProductProperty < ActiveRecord::Base
    belongs_to :product
    belongs_to :property

    validates :property, :presence => true
    validates_length_of :value, :maximum => 255

    attr_accessible :property_name, :value

    # virtual attributes for use with AJAX completion stuff
    def property_name
      property.name if property
    end

    def property_name=(name)
      unless name.blank?
        unless property = Property.find_by_name(name)
          property = Property.create(:name => name, :presentation => name)
        end
        self.property = property
      end
    end
  end
end
