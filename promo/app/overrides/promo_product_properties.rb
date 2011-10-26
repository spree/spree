Deface::Override.new(:virtual_path => "spree/products/show",
                     :name => "promo_product_properties",
                     :insert_after => "[data-hook='product_properties'], #product_properties[data-hook]",
                     :partial => "spree/products/promotions",
                     :disabled => false)
