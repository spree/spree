class Admin::ProductScopesController < Admin::BaseController
  helper 'admin/product_groups'

  resource_controller
  
  belongs_to :product_group
  
  actions :create, :destroy
  
  create.response do |wants| 
    wants.html { redirect_to edit_admin_product_group_path(parent_object) }
    wants.js { render :action => 'create', :layout => false}
  end
  destroy.response do |wants| 
    wants.html { redirect_to edit_admin_product_group_path(parent_object) }
    wants.js { render :action => 'destroy', :layout => false}
  end
  
end
