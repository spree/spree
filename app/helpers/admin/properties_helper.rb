module Admin::PropertiesHelper
  def cancel_button(label, div_id, show=nil, hide=nil)
    onclick =  %Q{Element.update('#{div_id}','');}
    onclick += %Q{Element.show('#{show}');} if show
    onclick += %Q{Element.hide('#{hide}');} if hide

    %Q{<button type="reset" onClick="#{onclick}">#{label}</button>}
  end
end
