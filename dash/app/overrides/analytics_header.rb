Deface::Override.new(:virtual_path => Spree::Config[:layout].gsub(/^\//, ''),
                     :name => "add_analytics_header",
                     :insert_bottom => "head",
                     :partial => "spree/analytics/header",
                     :original => '6f23c8af6e863d0499835c00b3f2763cb98e1d75')
