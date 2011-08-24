Deface::Override.new(:virtual_path => "checkout/_payment",
                     :name => "promo_coupon_code_field",
                     :replace => "[data-hook='coupon_code_field'], #coupon_code_field[data-hook]",
                     :partial => "checkout/coupon_code_field",
                     :disabled => false)
