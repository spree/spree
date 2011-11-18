Deface::Override.new(:virtual_path => "spree/layouts/admin",
                     :name => "promo_admin_tabs",
                     :insert_bottom => "[data-hook='admin_tabs'], #admin_tabs[data-hook]",
                     :text => "<%= tab(:promotions, :url => spree.admin_promotions_path) %>",
                     :disabled => false)
