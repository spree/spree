Deface::Override.new(:virtual_path => "spree/shared/_nav_bar",
                     :name => "auth_shared_login_bar",
                     :insert_after => "li#search-bar",
                     :partial => "spree/shared/login_bar",
                     :disabled => false)

