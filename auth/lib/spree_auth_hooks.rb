Deface::Override.new(:virtual_path => "layouts/admin",
                     :name => "auth_admin_login_navigation_bar",
                     :replace => "[data-hook='admin_login_navigation_bar'], #admin_login_navigation_bar[data-hook]",
                     :partial => "layouts/admin/login_nav",
                     :disabled => false)

Deface::Override.new(:virtual_path => "shared/_nav_bar",
                     :name => "auth_shared_login_bar",
                     :insert_after => "[data-hook='shared_login_bar'], #shared_login_bar[data-hook]",
                     :partial => "shared/login_bar",
                     :disabled => false)
