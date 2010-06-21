module Admin::ProductPropertiesHelper
  
  # Generates the appropriate field name for attribute_fu.  Normally attribute_fu handles this but we've got a 
  # special case where we need text_field_with_autocomplete and we have to recreate attribute_fu's naming 
  # scheme manually.
  def property_fu_name(product_property, number)
    if product_property.new_record?
      "product[product_property_attributes][new][#{number}][property_name]"
    else
      "product[product_property_attributes][#{product_property.id}][property_name]"   
    end
  end

  def property_fu_value(product_property, number)
    if product_property.new_record?
      "product[product_property_attributes][new][#{number}][value]"
    else
      "product[product_property_attributes][#{product_property.id}][value]"   
    end
  end
end