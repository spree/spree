module Spree
  class OptionType < Spree.base_class
    COLOR_NAMES = %w[color colour].freeze

    include Spree::ParameterizableName
    include Spree::UniqueName
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
    self.whitelisted_ransackable_scopes = %w[search_by_name]
    acts_as_list

    #
    # Associations
    with_options dependent: :destroy, inverse_of: :option_type do
      has_many :option_values, -> { order(:position) }
      has_many :product_option_types
    end
    has_many :products, through: :product_option_types
    has_many :option_type_prototypes, class_name: 'Spree::OptionTypePrototype'
    has_many :prototypes, through: :option_type_prototypes, class_name: 'Spree::Prototype'

    #
    # Validations
    #
    validates :presentation, presence: true

    #
    # Scopes
    #
    default_scope { order(:position) }
    scope :colors, -> { where(name: COLOR_NAMES) }
    scope :filterable, -> { where(filterable: true) }

    #
    # Attributes
    #
    accepts_nested_attributes_for :option_values, reject_if: lambda { |ov|
      ov[:id].blank? && (ov[:name].blank? || ov[:presentation].blank?)
    }, allow_destroy: true

    #
    # Callbacks
    #
    after_touch :touch_all_products
    after_update :touch_all_products, if: -> { saved_changes.key?(:presentation) }
    after_destroy :touch_all_products

    # legacy, name itself is now parameterized before saving
    def filter_param
      Spree::Deprecation.warn('Spree::OptionType#filter_param is deprecated and will be removed in Spree 6. Please use Spree::OptionType#name instead.')
      name.parameterize
    end

    def self.color
      colors.first
    end

    def color?
      name.in?(COLOR_NAMES)
    end

    private

    def touch_all_products
      products.touch_all
    end
  end
end
