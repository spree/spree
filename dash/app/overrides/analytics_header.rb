Deface::Override.new(:virtual_path => "spree/layouts/spree_application",
                     :name => "add_analytics_header",
                     :insert_bottom => "[data-hook='inside_head']",
                     :partial => "spree/analytics/header")
