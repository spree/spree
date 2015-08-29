module Spree
  class ProductProperty < Spree::Base
    acts_as_list scope: :product

    belongs_to :product, touch: true, inverse_of: :product_properties
    belongs_to :property, inverse_of: :product_properties

    validates :property, presence: true

    validates_with Spree::Validations::DbMaximumLengthValidator, field: :value

    default_scope { order(:position) }

    self.whitelisted_ransackable_attributes = ['value']

    # virtual attributes for use with AJAX completion stuff
    delegate :name, to: :property, allow_nil: true

    def property_name=(name)
      if name.present?
        # don't use `find_by :name` to workaround globalize/globalize#423 bug
        property = Property.where(name: name).first ||
                   Property.create(name: name, presentation: name)
        self.property = property
      end
    end
  end
end
