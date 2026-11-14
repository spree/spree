module Spree
  class OptionType < Spree.base_class
    has_prefix_id :opt  # Spree-specific: option type

    KINDS = %w[dropdown color_swatch buttons].freeze

    include Spree::ParameterizableName
    include Spree::SingleStoreResource
    include Spree::HasCustomFields
    include Spree::Metadata
    include Spree::LabelTranslatable

    TRANSLATABLE_FIELDS = Spree::LabelTranslatable::TRANSLATABLE_FIELDS

    # Option types are managed under the catalog, so the products permission guards them — see Admin::OptionTypesController.
    def self.translation_write_permission
      'write_products'
    end

    # Option values are translated alongside their type — the translations
    # endpoint nests their matrices so the editor fetches both in one read.
    def self.translatable_children
      :option_values
    end

    # The option names and values a write asks for that the store does not
    # offer, matched as `Variant#set_option_value` matches them. A seller
    # builds variants from these and never adds to them.
    #
    # @param store [Spree::Store]
    # @param pairs [Array<Array(String, String)>] option type names and value names
    # @return [Array<Hash>] one `{ name:, value:, option_type: }` per unknown pair;
    #   `option_type` is nil when the type itself is unknown
    def self.unknown_options(store, pairs)
      pairs = pairs.map { |name, value| [name.to_s, value.to_s] }.uniq { |name, value| [name.parameterize, value.parameterize] }
      return [] if pairs.empty?

      option_types = for_store(store).where(name: pairs.map { |name, _| name.parameterize }.uniq).index_by(&:name)
      # Only the values named, not every value of each type: Size can carry hundreds.
      known_values = Spree::OptionValue.where(option_type_id: option_types.values.map(&:id),
                                              name: pairs.map { |_, value| value.parameterize }.uniq).
                     pluck(:option_type_id, :name).to_set

      pairs.filter_map do |name, value|
        option_type = option_types[name.parameterize]
        next if option_type && known_values.include?([option_type.id, value.parameterize])

        { name: name, value: value, option_type: option_type }
      end
    end

    #
    # Magic methods
    #
    self.whitelisted_ransackable_scopes = %w[search_by_name]
    # `label` is what admin surfaces display, so it has to be filterable —
    # matching Spree::OptionValue, which already allows it.
    self.whitelisted_ransackable_attributes = %w[label name kind]
    search_by :name, :label

    normalizes :name, with: ->(value) { value&.to_s&.squish&.presence }

    validates :name, presence: true
    validates_store_uniqueness :name
    acts_as_list scope: :store_id

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
    has_many :option_type_product_types, class_name: 'Spree::OptionTypeProductType', dependent: :destroy
    has_many :product_types, through: :option_type_product_types, class_name: 'Spree::ProductType'

    #
    # Validations
    #
    validates :label, presence: true
    validates :kind, presence: true, inclusion: { in: KINDS }

    #
    # Scopes
    #
    default_scope { order(:position) }
    scope :filterable, -> { where(filterable: true) }

    #
    # Attributes
    #
    accepts_nested_attributes_for :option_values, reject_if: lambda { |ov|
      ov[:id].blank? && (ov[:name].blank? || ov[:label].blank?)
    }, allow_destroy: true

    #
    # Callbacks
    #
    after_touch :touch_all_products
    after_update :touch_all_products, if: -> { saved_changes.key?(:label) }
    after_destroy :touch_all_products

    def color_swatch?
      kind == 'color_swatch'
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
