module Spree
  # Which custom field definitions a ProductType uses, the order the dashboard
  # renders them in, and which it marks as required. `required` is advisory: the
  # product form shows a marker, but nothing rejects a blank value (Spree writes
  # a product and its custom fields in two steps — see the 2026-08-06 entry in
  # docs/plans/decisions.md). Read live by reference; no values are copied.
  class ProductTypeCustomFieldDefinition < Spree.base_class
    belongs_to :product_type, class_name: 'Spree::ProductType'
    # Association and column carry the 6.0 custom-field vocabulary; the class is
    # still named CustomFieldDefinition until the rename wave lands.
    belongs_to :custom_field_definition, class_name: 'Spree::CustomFieldDefinition'

    validates :custom_field_definition_id, uniqueness: { scope: :product_type_id }
    validate :custom_field_definition_applies_to_products

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
  end
end
