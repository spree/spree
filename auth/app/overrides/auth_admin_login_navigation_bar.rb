Deface::Override.new(:virtual_path => "spree/layouts/admin",
                     :name => "auth_admin_login_navigation_bar",
                     :replace => "[data-hook='admin_login_navigation_bar'], #admin_login_navigation_bar[data-hook]",
                     :partial => "spree/layouts/admin/login_nav")
