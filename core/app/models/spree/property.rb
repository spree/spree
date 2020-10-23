module Spree
  class Property < Spree::Base
    has_many :property_prototypes, class_name: 'Spree::PropertyPrototype'
    has_many :prototypes, through: :property_prototypes, class_name: 'Spree::Prototype'

    has_many :product_properties, dependent: :delete_all, inverse_of: :property
    has_many :products, through: :product_properties

    validates :name, :presentation, presence: true

    scope :sorted, -> { order(:name) }
    scope :filterable, -> { where(filterable: true) }

    after_touch :touch_all_products

    self.whitelisted_ransackable_attributes = ['presentation']

    def uniq_values
      product_properties.pluck(:value).compact.uniq
    end

    private

    def touch_all_products
      products.update_all(updated_at: Time.current)
    end
  end
end
