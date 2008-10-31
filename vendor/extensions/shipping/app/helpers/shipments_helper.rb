module ShipmentsHelper
  # Creates a radio button to represent a choice of shipping method.  The choice will be disabled if for some 
  # reason the rate is nil (perhaps the web service didn't return a quote for that method for some reason.)
  def shipping_radio(shipping_method, order)
    cost = shipping_method.calculate_shipping(@order)    
    checked = @shipment.shipping_method == shipping_method || @default_method == shipping_method
    if cost
      radio =  "<input type='radio' name='method_id' value='#{shipping_method.id}' #{"checked='true'" if checked} />" 
      radio += shipping_method.name
      radio += "&nbsp; (Cost: #{number_to_currency(cost)})"
    else
      radio =  "<input type='radio' name='method_id' disabled='true'/>"
      radio += "<span class='disabled'>#{shipping_method.name}</span>" 
    end
    radio
  end
end