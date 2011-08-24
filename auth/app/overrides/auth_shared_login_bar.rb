Deface::Override.new(:virtual_path => "shared/_nav_bar",
                     :name => "auth_shared_login_bar",
                     :insert_after => "li#search-bar",
                     :partial => "shared/login_bar",
                     :disabled => false)

