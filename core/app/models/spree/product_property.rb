module Spree
  class ProductProperty < Spree::Base
    acts_as_list scope: :product

    belongs_to :product, touch: true, class_name: 'Spree::Product', inverse_of: :product_properties
    belongs_to :property, class_name: 'Spree::Property', inverse_of: :product_properties

    validates :property, presence: true

    validates_with Spree::Validations::DbMaximumLengthValidator, field: :value

    default_scope { order("#{self.table_name}.position") }

    # virtual attributes for use with AJAX completion stuff
    def property_name
      property.name
    end
  end
end
