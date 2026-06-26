module Spree
  class OptionType < Spree.base_class
    has_prefix_id :opt  # Spree-specific: option type

    COLOR_NAMES = %w[color colour].freeze
    KINDS = %w[dropdown color_swatch buttons].freeze

    include Spree::ParameterizableName
    include Spree::UniqueName
    include Spree::Metafields
    include Spree::Metadata
    # presentation column, exposed publicly as `label` + translated via Mobility.
    include Spree::PresentationTranslatable

    TRANSLATABLE_FIELDS = Spree::PresentationTranslatable::TRANSLATABLE_FIELDS

    # Option values are translated alongside their type — the translations
    # endpoint nests their matrices so the editor fetches both in one read.
    def self.translatable_children
      :option_values
    end

    self::Translation.class_eval do
      normalizes :presentation, with: ->(value) { value&.to_s&.squish&.presence }
    end

    #
    # Magic methods
    #
    self.whitelisted_ransackable_scopes = %w[search_by_name]
    acts_as_list

    #
    # Associations
    with_options dependent: :destroy, inverse_of: :option_type do
      # `autosave: true` makes the parent's `save`/`update`:
      #   - persist any built / mutated children in one transaction,
      #   - collect their validation errors onto `self.errors`,
      #   - destroy any child marked via `mark_for_destruction`.
      # The custom `option_values=` writer below leans on this so the v3
      # ResourceController gets `save returning false` + structured errors
      # rather than raised exceptions.
      has_many :option_values, -> { order(:position) }, autosave: true
      has_many :product_option_types
    end
    has_many :products, through: :product_option_types
    has_many :option_type_prototypes, class_name: 'Spree::OptionTypePrototype'
    has_many :prototypes, through: :option_type_prototypes, class_name: 'Spree::Prototype'

    # 5.5 API naming bridge (`label` → `presentation`) lives in
    # Spree::PresentationTranslatable.

    #
    # Validations
    #
    validates :presentation, presence: true
    validates :kind, presence: true, inclusion: { in: KINDS }

    #
    # Scopes
    #
    default_scope { order(:position) }
    scope :colors, -> { where(name: COLOR_NAMES) }
    scope :color_swatches, -> { where(kind: 'color_swatch') }
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

    def self.color
      colors.first
    end

    def color_swatch?
      kind == 'color_swatch'
    end

    def color?
      Spree::Deprecation.warn(
        'Spree::OptionType#color? is deprecated. Use #color_swatch? instead. Will be removed in Spree 6.0.'
      )
      color_swatch?
    end

    # Syncs option values from an array of hashes by mutating the in-memory
    # `option_values` association — built/assigned children get persisted by
    # `autosave: true` when the parent saves, and absent IDs get destroyed
    # via `mark_for_destruction`. The single transaction is owned by the
    # parent's `save`, so validation failures surface as `errors` and the
    # whole thing rolls back together.
    #
    # Falls back to ActiveRecord's collection writer when given OptionValue
    # records (e.g. from `accepts_nested_attributes_for` used by the legacy admin).
    #
    # @param option_values_params [Array<Hash>] array of option value attribute hashes
    # @return [void]
    def option_values=(option_values_params)
      return super if option_values_params.blank? || option_values_params.first.is_a?(Spree::OptionValue)

      # Load the association into the in-memory collection so subsequent
      # `option_values.build` / `mark_for_destruction` mutations stay on the
      # same instances `autosave` will traverse at parent-save time.
      existing_by_id = option_values.to_a.index_by(&:id)
      retained_ids = []

      option_values_params.each do |value_data|
        data = value_data.to_h.with_indifferent_access
        value_id = data.delete(:id)

        record = if value_id.present?
                   existing_by_id[Spree::PrefixedId.decode_prefixed_id(value_id) || value_id] ||
                     raise(ActiveRecord::RecordNotFound.new("Couldn't find Spree::OptionValue with param=#{value_id}", 'Spree::OptionValue'))
                 else
                   option_values.build
                 end
        record.assign_attributes(data)
        retained_ids << record.id if record.persisted?
      end

      existing_by_id.each_value do |existing|
        existing.mark_for_destruction unless retained_ids.include?(existing.id)
      end
    end

    private

    def touch_all_products
      products.touch_all
    end
  end
end
