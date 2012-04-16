Deface::Override.new(:virtual_path => "spree/layouts/spree_application",
                     :name => "add_analytics_header",
                     :insert_bottom => "[data-hook='inside_head']",
                     :partial => "spree/analytics/header"),
                     :original => '6f23c8af6e863d0499835c00b3f2763cb98e1d75'
