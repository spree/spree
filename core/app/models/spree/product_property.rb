module Spree
  class ProductProperty < Spree::Base
    acts_as_list scope: :product

    with_options inverse_of: :product_properties do
      belongs_to :product, touch: true, class_name: 'Spree::Product'
      belongs_to :property, class_name: 'Spree::Property'
    end

    validates :property, presence: true
    validates :value, db_maximum_length: true
    validates :property_id, uniqueness: { scope: :product_id }, allow_blank: true

    default_scope { order(:position) }

    self.whitelisted_ransackable_attributes = ['value']
    self.whitelisted_ransackable_associations = ['property']

    # virtual attributes for use with AJAX completion stuff
    delegate :name, to: :property, prefix: true, allow_nil: true

    def property_name=(name)
      if name.present?
        # don't use `find_by :name` to workaround globalize/globalize#423 bug
        stripped_name = name.strip
        self.property = Property.where(name: stripped_name).first_or_create(presentation: stripped_name)
      end
    end
  end
end
