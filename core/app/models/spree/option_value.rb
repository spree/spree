module Spree
  class OptionValue < Spree.base_class
    include Spree::ParameterizableName
    include Spree::Metafields
    include Spree::Metadata
    include Spree::TranslatableResource
    if defined?(Spree::Webhooks::HasWebhooks)
      include Spree::Webhooks::HasWebhooks
    end

    TRANSLATABLE_FIELDS = %i[presentation].freeze
    translates(*TRANSLATABLE_FIELDS, column_fallback: !Spree.always_use_translations?)

    self::Translation.class_eval do
      auto_strip_attributes :presentation
    end

    #
    # Magic methods
    #
    acts_as_list scope: :option_type
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
      # we need to use map(&:id) to avoid SQL errors when merging with other scopes
      joins(:variants).where(Spree::Variant.table_name => { product_id: products.map(&:id) })
    }

    #
    # Callbacks
    #
    after_touch :touch_all_variants
    after_update :touch_all_products, if: -> { saved_changes.key?(:presentation) }
    after_touch :touch_all_products

    delegate :name, :presentation, to: :option_type, prefix: true, allow_nil: true

    # Using map here instead of pluck, as these values are translatable via Mobility gem
    # @return [Array<Hash>]
    def self.to_tom_select_json
      all.map do |ov|
        {
          id: ov.name,
          name: ov.presentation
        }
      end
    end

    # Returns the presentation with the option type presentation, eg. "Color: Red"
    # @return [String]
    def display_presentation
      @display_presentation ||= "#{option_type.presentation}: #{presentation}"
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
