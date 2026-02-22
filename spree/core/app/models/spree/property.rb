module Spree
  class Property < Spree.base_class
    include Spree::FilterParam
    include Spree::Metadata
    include Spree::ParameterizableName
    include Spree::UniqueName
    include Spree::DisplayOn
    include Spree::TranslatableResource

    TRANSLATABLE_FIELDS = %i[presentation].freeze
    translates(*TRANSLATABLE_FIELDS, column_fallback: !Spree.always_use_translations?)

    self::Translation.class_eval do
      normalizes :presentation, with: ->(value) { value&.to_s&.squish&.presence }
    end

    acts_as_list

    has_many :property_prototypes, class_name: 'Spree::PropertyPrototype'
    has_many :prototypes, through: :property_prototypes, class_name: 'Spree::Prototype'

    has_many :product_properties, dependent: :delete_all, inverse_of: :property
    has_many :products, through: :product_properties

    validates :name, :presentation, presence: true

    default_scope { order(:position) }
    scope :sorted, -> { order(:name) }
    scope :filterable, -> { where(filterable: true) }

    KIND_OPTIONS = { short_text: 0, long_text: 1, number: 2, rich_text: 3 }.freeze
    enum :kind, KIND_OPTIONS

    DEPENDENCY_UPDATE_FIELDS = [:presentation, :name, :kind, :filterable, :display_on, :position].freeze

    after_touch :touch_all_products
    after_update :touch_all_products, if: -> { DEPENDENCY_UPDATE_FIELDS.any? { |field| saved_changes.key?(field) } }
    after_save :ensure_product_properties_have_filter_params

    self.whitelisted_ransackable_attributes = ['presentation', 'filterable']

    def uniq_values(product_properties_scope: nil)
      with_uniq_values_cache_key(product_properties_scope) do
        properties = product_properties
        properties = properties.where(id: product_properties_scope) if product_properties_scope.present?
        properties.where('value IS NOT NULL AND value != ?', '').pluck(:filter_param, :value).uniq
      end
    end

    # Returns the metafield type for the property kind
    # @return [String] eg. 'Spree::Metafields::ShortText'
    def kind_to_metafield_type
      case kind
      when 'short_text'
        'Spree::Metafields::ShortText'
      when 'long_text'
        'Spree::Metafields::LongText'
      when 'number'
        'Spree::Metafields::Number'
      when 'rich_text'
        'Spree::Metafields::RichText'
      else
        'Spree::Metafields::ShortText'
      end
    end

    private

    def touch_all_products
      products.touch_all
    end

    def with_uniq_values_cache_key(product_properties_scope, &block)
      return block.call if product_properties_scope.present?

      uniq_values_cache_key = ['property-uniq-values', cache_key_with_version]
      Rails.cache.fetch(uniq_values_cache_key) { block.call }
    end

    def ensure_product_properties_have_filter_params
      return unless filterable?

      product_properties.where(filter_param: [nil, '']).where('value IS NOT NULL AND value != ?', '').find_each(&:save)
    end
  end
end
