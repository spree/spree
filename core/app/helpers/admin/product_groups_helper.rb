module Admin::ProductGroupsHelper

  # Allow certain scope attributes to have a custom field type
  def product_scope_field(product_scope, i)
    value = (product_scope.arguments || [])[i]
    name = "product_group[product_scopes_attributes][][arguments][]"
    helper_method_for_scope = Scopes::Product::ATTRIBUTE_HELPER_METHODS[product_scope.name.to_sym] || :text_field_tag
    send(helper_method_for_scope, name, value)
  end
    
end
