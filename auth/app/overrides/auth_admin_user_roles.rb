Deface::Override.new(:virtual_path => "spree/admin/users/_form",
                     :name => "auth_admin_user_roles",
                     :insert_after => "[data-hook='admin_user_form_fields']",
                     :partial => "spree/admin/users/roles",
                     :disabled => false)
