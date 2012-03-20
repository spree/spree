Deface::Override.new(:virtual_path => "spree/admin/payment_methods/index",
                     :name => "gateway_banner",
                     :insert_after => "#listing_payment_methods",
                     :partial => "spree/admin/banners/gateway")


