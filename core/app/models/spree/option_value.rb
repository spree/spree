module Spree
  class OptionValue < Spree.base_class
    include Spree::ParameterizableName
    include Spree::Metadata
    include Spree::TranslatableResource
    if defined?(Spree::Webhooks::HasWebhooks)
      include Spree::Webhooks::HasWebhooks
    end

    if Spree.always_use_translations?
      TRANSLATABLE_FIELDS = %i[name presentation].freeze
      translates(*TRANSLATABLE_FIELDS)
    else
      TRANSLATABLE_FIELDS = %i[presentation].freeze
      translates(*TRANSLATABLE_FIELDS, column_fallback: true)
    end

    #
    # Magic methods
    #
    acts_as_list scope: :option_type
    auto_strip_attributes :name, :presentation
    self.whitelisted_ransackable_attributes = ['presentation']

    #
    # Associations
    #
    belongs_to :option_type, class_name: 'Spree::OptionType', touch: true, inverse_of: :option_values
    has_many :option_value_variants, class_name: 'Spree::OptionValueVariant'
    has_many :variants, through: :option_value_variants, class_name: 'Spree::Variant'
    has_many :products, through: :variants, class_name: 'Spree::Product'

    #
    # Validations
    #
    with_options presence: true do
      validates :name, uniqueness: { scope: :option_type_id, case_sensitive: false }
      validates :presentation
    end

    #
    # Scopes
    #
    scope :filterable, lambda {
      joins(:option_type).
        where(OptionType.table_name => { filterable: true }).
        distinct
    }

    scope :for_products, lambda { |products|
      joins(:variants).
        where(Variant.table_name => { product_id: products.map(&:id) })
    }

    #
    # Callbacks
    #
    after_touch :touch_all_variants
    after_update :touch_all_products, if: -> { saved_changes.key?(:presentation) }
    after_touch :touch_all_products

    delegate :name, :presentation, to: :option_type, prefix: true, allow_nil: true

    def self.to_tom_select_json
      all.pluck(:name, :presentation).map do |name, presentation|
        {
          id: name,
          name: presentation
        }
      end
    end

    private

    def touch_all_variants
      variants.touch_all
    end

    def touch_all_products
      products.touch_all
    end
  end
end
