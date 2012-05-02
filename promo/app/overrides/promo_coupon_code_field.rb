Deface::Override.new(:virtual_path => "spree/checkout/_payment",
                     :name => "promo_coupon_code_field",
                     :replace => "[data-hook='coupon_code_field'], #coupon_code_field[data-hook]",
                     :partial => "spree/checkout/coupon_code_field",
                     :disabled => false,
                     :original => '9c9f7058eb6fd9236a241621ab53b43e1caa1a0b' )
