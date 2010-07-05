class PromotionsHooks < Spree::ThemeSupport::HookListener
  
  insert_after :admin_tabs do
    %(<%= tab(:promotions) %>)
  end
  
  insert_after :product_properties, 'products/promotions'
    
end
