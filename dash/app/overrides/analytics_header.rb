Deface::Override.new(:virtual_path => "spree/admin/shared/_configuration_menu",
                     :name => "add_dashboard_sidebar_link",
                     :insert_bottom => ".sidebar",
                     :text => "<%= configurations_sidebar_menu_item t(:jirafe), admin_analytics_path %>",
                     :original => 'a74f177275dc303c9cd5994b2e24e027434c3cbb')
