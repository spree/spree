if defined?(Deface)
  Deface::Override.new(:virtual_path => "spree/admin/users/edit",
                       :name => "api_admin_user_edit_form",
                       :insert_after => "[data-hook='admin_user_edit_general_settings']",
                       :partial => "spree/admin/users/api_fields",
                       :disabled => false)
end
