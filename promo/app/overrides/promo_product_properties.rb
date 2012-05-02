Deface::Override.new(:virtual_path => "spree/products/show",
                     :name => "promo_product_properties",
                     :insert_after => "[data-hook='product_properties'], #product_properties[data-hook]",
                     :partial => "spree/products/promotions",
                     :disabled => false,
                     :original => '21a1d0ddb6ae24042f130d64f0ad4b90e69cd088')
