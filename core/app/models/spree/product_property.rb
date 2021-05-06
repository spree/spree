module Spree
  class ProductProperty < Spree::Base
    include Spree::FilterParam

    auto_strip_attributes :value

    acts_as_list scope: :product

    with_options inverse_of: :product_properties do
      belongs_to :product, touch: true, class_name: 'Spree::Product'
      belongs_to :property, class_name: 'Spree::Property'
    end

    validates :property, presence: true

    default_scope { order(:position) }

    self.whitelisted_ransackable_attributes = ['value', 'filter_param']
    self.whitelisted_ransackable_associations = ['property']

    # virtual attributes for use with AJAX completion stuff
    delegate :name, :presentation, to: :property, prefix: true, allow_nil: true

    def property_name=(name)
      ActiveSupport::Deprecation.warn(<<-DEPRECATION, caller)
        `ProductProperty#property_name=` is deprecated and will be removed in Spree 5.0.
      DEPRECATION
      if name.present?
        # don't use `find_by :name` to workaround globalize/globalize#423 bug
        self.property = Property.where(name: name).first_or_create(presentation: name)
      end
    end

    protected

    def param_candidate
      value
    end
  end
end
