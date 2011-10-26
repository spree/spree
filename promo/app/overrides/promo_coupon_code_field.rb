Deface::Override.new(:virtual_path => "spree/checkout/_payment",
                     :name => "promo_coupon_code_field",
                     :replace => "[data-hook='coupon_code_field'], #coupon_code_field[data-hook]",
                     :partial => "spree/checkout/coupon_code_field",
                     :disabled => false)
