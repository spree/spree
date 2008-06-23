module Admin::PrototypesHelper
  def cancel_button(label, div_id, show=nil, hide=nil)
    onclick =  %Q{Element.update('#{div_id}','');}
    onclick += %Q{Element.show('#{show}');} if show
    onclick += %Q{Element.hide('#{hide}');} if hide

    %Q{<button type="reset" onClick="#{onclick}">#{label}</button>}
  end

  def exclusive_properties(prototype, properties)
    prototype.properties.each do |prop|
      logger.debug("proto property: #{prop.inspect}")
      properties.delete(prop)
#      properties = properties.delete_if { |p| p.id == pp.product_property_id }
    end
    properties
  end
end
