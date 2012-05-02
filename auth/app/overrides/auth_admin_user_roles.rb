Deface::Override.new(:virtual_path => "spree/admin/users/_form",
                     :name => "auth_admin_user_roles",
                     :insert_after => "[data-hook='admin_user_form_fields']",
                     :partial => "spree/admin/users/roles",
                     :disabled => false,
                     :original => '0e121156115799a53f5c5dddfb65c1ec80cb5f09')
