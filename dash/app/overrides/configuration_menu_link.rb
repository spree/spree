Deface::Override.new(:virtual_path => "spree/admin/configurations/index",
                     :name => "add_dashboard_sidebar_link",
                     :insert_bottom => "tbody[data-hook=admin_configurations_menu]",
                     :partial => "spree/admin/dash/configurations/jirafe",
                     :original => 'a74f177275dc303c9cd5994b2e24e027434c3cbb')
