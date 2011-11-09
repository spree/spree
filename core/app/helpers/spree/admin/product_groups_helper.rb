module Spree
  module Admin
    module ProductGroupsHelper
      # Allow certain scope attributes to have a custom field type
      def product_scope_field(product_scope, i)
        value = (product_scope.arguments || [])[i]
        name = 'product_group[product_scopes_attributes][][arguments][]'
        helper_method_for_scope = :product_picker_field if product_scope.name.to_sym == :with_ids
        helper_method_for_scope ||= :text_field_tag
        send(helper_method_for_scope, name, value)
      end
    end
  end
end
