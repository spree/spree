module Spree
  class ProductProperty < Spree::Base
    include Spree::FilterParam
    include Spree::TranslatableResource

    if Spree.always_use_translations?
      TRANSLATABLE_FIELDS = %i[value filter_param].freeze
      translates(*TRANSLATABLE_FIELDS)
    else
      TRANSLATABLE_FIELDS = %i[value].freeze
      translates(*TRANSLATABLE_FIELDS, column_fallback: true)
    end

    self::Translation.class_eval do
      auto_strip_attributes :value
    end

    auto_strip_attributes :value

    acts_as_list scope: :product

    with_options inverse_of: :product_properties do
      belongs_to :product, touch: true, class_name: 'Spree::Product'
      belongs_to :property, touch: true, class_name: 'Spree::Property'
    end

    validates :property, presence: true
    validates :property_id, uniqueness: { scope: :product_id }
    validates :value, presence: true

    default_scope { order(:position) }

    scope :filterable, -> { joins(:property).where(Property.table_name => { filterable: true }) }
    scope :for_products, ->(products) { joins(:product).merge(products) }

    self.whitelisted_ransackable_attributes = ['value', 'filter_param']
    self.whitelisted_ransackable_associations = ['property']

    # virtual attributes for use with AJAX completion stuff
    delegate :name, :presentation, to: :property, prefix: true, allow_nil: true

    def property_name=(name)
      Spree::Deprecation.warn(<<-DEPRECATION, caller)
        `ProductProperty#property_name=` is deprecated and will be removed in Spree 5.0.
      DEPRECATION
      if name.present?
        self.property = if Property.where(name: name).exists?
                          Property.where(name: name).first
                        else
                          Property.create(name: name, presentation: name)
                        end
      end
    end

    protected

    def param_candidate
      value
    end
  end
end
