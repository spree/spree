module Spree
  class OptionValue < Spree.base_class
    has_prefix_id :optval  # Spree-specific: option value

    include Spree::ParameterizableName
    include Spree::HasCustomFields
    include Spree::Metadata
    include Spree::LabelTranslatable

    TRANSLATABLE_FIELDS = Spree::LabelTranslatable::TRANSLATABLE_FIELDS

    #
    # Magic methods
    #
    acts_as_list scope: :option_type
    self.whitelisted_ransackable_attributes = ['label']

    #
    # Attachments
    #
    has_one_attached :image

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
      validates :label
    end

    validates :color_code, format: { with: /\A#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?\z/, message: 'must be a valid hex color (e.g. #FF0000)' },
                           allow_blank: true

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
    after_update :touch_all_products, if: -> { saved_changes.key?(:label) }
    after_touch :touch_all_products

    delegate :name, :label, to: :option_type, prefix: true, allow_nil: true

    # @deprecated The delegated name follows the renamed column since 6.0;
    #   removed in 6.1.
    alias option_type_presentation option_type_label

    # Using map here instead of pluck, as these values are translatable via Mobility gem
    # @deprecated Legacy Tom Select helper for the removed Rails admin. No replacement.
    # @return [Array<Hash>]
    def self.to_tom_select_json
      Spree::Deprecation.warn('Spree::OptionValue.to_tom_select_json is deprecated and will be removed in Spree 6.1.')

      all.map do |ov|
        {
          id: ov.name,
          name: ov.label
        }
      end
    end

    # Returns the presentation with the option type presentation, eg. "Color: Red"
    # @deprecated No replacement, build the label in the presentation layer instead.
    # @return [String]
    def display_presentation
      Spree::Deprecation.warn('Spree::OptionValue#display_presentation is deprecated and will be removed in Spree 6.1.')

      @display_presentation ||= "#{option_type.label}: #{label}"
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
