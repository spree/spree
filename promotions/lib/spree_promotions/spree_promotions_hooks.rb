class PromotionsHooks < Spree::ThemeSupport::HookListener

  insert_after :admin_configurations_menu do
    %(
    <tr>
      <td><%= link_to t("promotions"), admin_promotions_path %></td>
      <td><%= t("promotions_description") %></td>
    </tr>
    )
  end
  
  insert_after :product_properties, 'products/promotions'
    
end
