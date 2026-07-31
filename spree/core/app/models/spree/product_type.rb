module Spree
  class ProductType < Spree.base_class
    has_prefix_id :pt

    include Spree::Metadata
    include Spree::TranslatableResource
    include Spree::SingleStoreResource

    TRANSLATABLE_FIELDS = %i[name].freeze
    translates(*TRANSLATABLE_FIELDS, column_fallback: Spree.mobility_column_fallback)

    attribute :fulfillment_types, default: -> { ['shipping'] }

    belongs_to :store, class_name: 'Spree::Store'

    has_many :option_type_product_types, class_name: 'Spree::OptionTypeProductType', dependent: :destroy
    has_many :option_types, through: :option_type_product_types, class_name: 'Spree::OptionType'

    has_many :product_type_categories, class_name: 'Spree::ProductTypeCategory', dependent: :destroy
    has_many :categories, through: :product_type_categories, class_name: 'Spree::Category'

    # restrict, not nullify — removing a product's type (deletion included) would
    # invalidate its type-driven data, so types in use cannot be deleted
    has_many :products, class_name: 'Spree::Product', dependent: :restrict_with_error

    validates :name, presence: true, uniqueness: { case_sensitive: false, scope: :store_id }
    validates :store, presence: true
    validates :fulfillment_types, presence: true

    self.whitelisted_ransackable_attributes = %w[name]
    self.whitelisted_ransackable_associations = %w[option_types]

    # @return [Boolean] true when products of this type are delivered digitally only
    def digital?
      fulfillment_types == ['digital']
    end

    # @return [Boolean] true when products of this type require physical delivery
    def requires_shipping?
      fulfillment_types.include?('shipping')
    end
  end
end
