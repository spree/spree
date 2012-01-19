Deface::Override.new(:virtual_path => "spree/shared/_nav_bar",
                     :name => "auth_shared_login_bar",
                     :insert_before => "li#search-bar",
                     :partial => "spree/shared/login_bar",
                     :disabled => false)

