Deface::Override.new(:virtual_path => "spree/layouts/admin",
                     :name => "promo_admin_tabs",
                     :insert_bottom => "[data-hook='admin_tabs'], #admin_tabs[data-hook]",
                     :text => "<% if respond_to?(:spree_promo) %><%= tab(:promotions, :url => spree_promo.admin_promotions_path) %><% end %>",
                     :disabled => false)
