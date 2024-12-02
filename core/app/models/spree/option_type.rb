module Spree
  class OptionType < Spree.base_class
    COLOR_NAMES = %w[color colour].freeze

    include Spree::ParameterizableName
    include Spree::UniqueName
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
    self.whitelisted_ransackable_scopes = %w[search_by_name]
    acts_as_list
    auto_strip_attributes :name, :presentation

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

    if defined?(PgSearch)
      # full text search
      include PgSearch::Model
      pg_search_scope :search_by_name, against: %i[name presentation]
    else
      scope :search_by_name, ->(query) { where('name LIKE ?', "%#{query}%") }
    end

    #
    # Attributes
    #
    accepts_nested_attributes_for :option_values, reject_if: ->(ov) { ov[:name].blank? || ov[:presentation].blank? }, allow_destroy: true

    #
    # Callbacks
    #
    after_touch :touch_all_products
    after_update :touch_all_products, if: -> { saved_changes.key?(:presentation) }
    after_destroy :touch_all_products

    # legacy, name itself is now parameterized before saving
    def filter_param
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
