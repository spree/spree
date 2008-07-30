module Admin::BaseHelper
  
  def link_to_edit(resource)
    link_to t("Edit"), edit_object_url(resource)
  end
  
  def link_to_delete(resource)
    link_to t("Delete"), object_url(resource), :confirm => "Are you sure you want to delete this record?", :method => :delete 
  end
  
end
