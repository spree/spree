module Admin::BaseHelper
  
  def link_to_edit(resource)
    link_to t("edit"), edit_object_url(resource)
  end
  
  def link_to_delete(resource)
    link_to t("delete"), object_url(resource), :confirm => t('are_you_sure'), :method => :delete 
  end
  
  def get_additional_field_value(controller, field)  
    attribute = field[:name].gsub(" ", "_").downcase

    value = eval("@" + controller.controller_name.singularize + "." + attribute)  
    
    if value.nil? && controller.controller_name == "variants"
      value = @variant.product.has_attribute?(attribute) ? @variant.product[attribute] : nil
    end

    if value.nil?
      return value
    else
      return field.key?(:format) ? sprintf(field[:format], value) : value
    end
  end
  
end
