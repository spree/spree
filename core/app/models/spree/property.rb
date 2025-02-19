module Spree
  class Property < Spree.base_class
    include Spree::FilterParam
    include Spree::Metadata
    include Spree::ParameterizableName
    include Spree::DisplayOn
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

    self::Translation.class_eval do
      auto_strip_attributes :presentation
    end

    auto_strip_attributes :name, :presentation
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

    after_touch :touch_all_products
    after_update :touch_all_products, if: -> { saved_changes.key?(:presentation) }
    after_save :ensure_product_properties_have_filter_params

    self.whitelisted_ransackable_attributes = ['presentation', 'filterable']

    def uniq_values(product_properties_scope: nil)
      with_uniq_values_cache_key(product_properties_scope) do
        properties = product_properties
        properties = properties.where(id: product_properties_scope) if product_properties_scope.present?
        properties.where.not(value: [nil, '']).pluck(:filter_param, :value).uniq
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

      product_properties.where(filter_param: [nil, '']).where.not(value: [nil, '']).find_each(&:save)
    end
  end
end
