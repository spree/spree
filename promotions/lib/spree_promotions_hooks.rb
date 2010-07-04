class PromotionsHooks < Spree::ThemeSupport::HookListener
  
  # Atm hook modifiers with block don't supported with Rails 3
  # insert_after :admin_tabs do
  #   %(<%= tab(:promotions) %>)
  # end
 
  insert_after :admin_tabs, 'admin/promotions/tab'
  
  insert_after :product_properties, 'products/promotions'
    
end
