class SpreePromoHooks < Spree::ThemeSupport::HookListener

  insert_after :admin_tabs do
    %(<%= tab(:promotions) %>)
  end

  insert_after :product_properties, 'products/promotions'

  replace :coupon_code_field, 'checkout/coupon_code_field'

end
