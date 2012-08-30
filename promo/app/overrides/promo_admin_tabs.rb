Deface::Override.new(:virtual_path => "spree/layouts/admin",
                     :name => "promo_admin_tabs",
                     :insert_bottom => "[data-hook='admin_tabs'], #admin_tabs[data-hook]",
                     :text => "<%= tab(:promotions, :url => spree.admin_promotions_path, :icon => 'icon-bullhorn') %>",
                     :disabled => false,
                     :original => '3e847740dc3e7f924aba1ccb4cb00c7b841649e3')
