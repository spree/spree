Deface::Override.new(:virtual_path => "products/show",
                     :name => "promo_product_properties",
                     :insert_after => "[data-hook='product_properties'], #product_properties[data-hook]",
                     :partial => "products/promotions",
                     :disabled => false)
