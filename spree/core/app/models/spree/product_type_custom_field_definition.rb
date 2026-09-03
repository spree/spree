module Spree
  # Which custom field definitions a ProductType uses, the order the dashboard
  # renders them in, and which it marks as required. `required` is advisory: the
  # product form shows a marker, but nothing rejects a blank value (Spree writes
  # a product and its custom fields in two steps — see the 2026-08-06 entry in
  # docs/plans/decisions.md). Read live by reference; no values are copied.
  class ProductTypeCustomFieldDefinition < Spree.base_class
    belongs_to :product_type, class_name: 'Spree::ProductType'
    belongs_to :custom_field_definition, class_name: 'Spree::CustomFieldDefinition'

    validates :custom_field_definition_id, uniqueness: { scope: :product_type_id }
    validate :custom_field_definition_applies_to_products
    validate :custom_field_definition_belongs_to_same_store

    scope :required, -> { where(required: true) }
    scope :ordered, -> { order(:sort_order, :id) }

    private

    # A type describes products, so a definition scoped to another resource
    # (Order, Customer) would render a field the product form can never fill.
    def custom_field_definition_applies_to_products
      return if custom_field_definition.blank?
      return if custom_field_definition.resource_type == 'Spree::Product'

      errors.add(:custom_field_definition, :must_apply_to_products)
    end

    # Both sides are store-owned, so a type may only use its own store's
    # definitions — one from another store would render a field the product
    # form can never save.
    def custom_field_definition_belongs_to_same_store
      return if custom_field_definition.blank? || product_type.blank?
      return if custom_field_definition.store_id == product_type.store_id

      errors.add(:custom_field_definition, :must_belong_to_same_store)
    end
  end
end
