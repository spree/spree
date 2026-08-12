module Spree
  class ProductType < Spree.base_class
    has_prefix_id :pt

    include Spree::HasCustomFields
    include Spree::Metadata
    include Spree::TranslatableResource
    include Spree::SingleStoreResource

    TRANSLATABLE_FIELDS = %i[name].freeze
    translates(*TRANSLATABLE_FIELDS, column_fallback: Spree.mobility_column_fallback)

    belongs_to :store, class_name: 'Spree::Store'
    # Creation-time template only: stamped onto the product when it is
    # created with this type, never managed through it afterwards — the same
    # doctrine as every other type-driven attribute. Nil means the store's
    # default profile.
    belongs_to :delivery_profile, class_name: 'Spree::DeliveryProfile', optional: true

    has_many :option_type_product_types, class_name: 'Spree::OptionTypeProductType', dependent: :destroy
    has_many :option_types, through: :option_type_product_types, class_name: 'Spree::OptionType'

    has_many :product_type_categories, class_name: 'Spree::ProductTypeCategory', dependent: :destroy
    has_many :categories, through: :product_type_categories, class_name: 'Spree::Category'

    has_many :product_type_custom_field_definitions, -> { ordered },
             class_name: 'Spree::ProductTypeCustomFieldDefinition', dependent: :destroy, inverse_of: :product_type
    has_many :custom_field_definitions, through: :product_type_custom_field_definitions,
             class_name: 'Spree::CustomFieldDefinition'

    # restrict, not nullify — removing a product's type (deletion included) would
    # invalidate its type-driven data, so types in use cannot be deleted
    has_many :products, class_name: 'Spree::Product', dependent: :restrict_with_error

    after_save :apply_pending_custom_field_definitions, if: -> { @pending_custom_field_definitions }

    validates :name, presence: true, uniqueness: { case_sensitive: false, scope: :store_id }
    validates :store, presence: true

    self.whitelisted_ransackable_attributes = %w[name]
    self.whitelisted_ransackable_associations = %w[option_types]

    # Replace-set writer for the flat API payload. Each entry is
    # `{ id: 'cfdef_…', required: true, sort_order: 0 }` — rows not listed are
    # removed from the type. Editing the list never touches products; the form
    # is generated from it live.
    #
    # @param rows [Array<Hash>, nil]
    # @return [void]
    def custom_field_definitions=(rows)
      return super if rows.blank? || rows.first.is_a?(Spree::CustomFieldDefinition)

      @pending_custom_field_definitions = Array(rows).map { |row| row.to_h.with_indifferent_access }
    end

    # @return [Array<String>] prefixed option type ids, encoded from the ids to
    #   avoid hydrating the records just to serialize them
    def option_type_prefixed_ids
      option_type_ids.map { |id| Spree::OptionType.prefixed_id_for(id) }
    end

    # @return [Array<String>] prefixed category ids
    def category_prefixed_ids
      category_ids.map { |id| Spree::Category.prefixed_id_for(id) }
    end


    private

    # Applied after save so a newly created type has an id to join against.
    # Ids arrive prefixed from the API and raw from console/importer callers, so
    # each row is resolved once here and carried through both passes.
    def apply_pending_custom_field_definitions
      rows = @pending_custom_field_definitions
      @pending_custom_field_definitions = nil

      resolved = rows.map do |row|
        [Spree::CustomFieldDefinition.find_by_prefix_id(row[:id]), row]
      end

      # Validate the whole payload before touching anything. This runs inside
      # the save's own transaction, so a rollback raised partway through would
      # be swallowed — the only safe point to refuse is before the delete.
      invalid = resolved.reject { |definition, _row| definition&.resource_type == 'Spree::Product' }
      if invalid.any?
        invalid.each do |definition, row|
          errors.add(
            :custom_field_definitions,
            definition.nil? ? "unknown definition: #{row[:id]}" : "#{definition.key} is not a product custom field"
          )
        end
        return
      end

      definition_ids = resolved.map { |definition, _row| definition.id }
      product_type_custom_field_definitions.
        where.not(custom_field_definition_id: definition_ids).destroy_all

      existing_joins = product_type_custom_field_definitions.index_by(&:custom_field_definition_id)

      resolved.each_with_index do |(definition, row), index|
        join = existing_joins[definition.id] ||
               product_type_custom_field_definitions.build(custom_field_definition_id: definition.id)
        join.required = row[:required]
        join.sort_order = row[:sort_order] || index
        join.save
      end

      product_type_custom_field_definitions.reset
    end

  end
end
