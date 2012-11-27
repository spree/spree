Deface::Override.new(:virtual_path => "spree/orders/edit",
                     :name => "promo_cart_coupon_code_field",
                     :insert_after => "[data-hook='cart_buttons']",
                     :partial => "spree/orders/coupon_code_field",
                     :disabled => false,
                     :original => "c11d9a1996fb86e992aba19035074cf5f688dea2")
