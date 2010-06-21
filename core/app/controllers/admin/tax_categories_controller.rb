class Admin::TaxCategoriesController < Admin::BaseController
  resource_controller
  
  create.response do |wants|
    wants.html { redirect_to collection_url }
  end

  update.response do |wants|
    wants.html { redirect_to collection_url }
  end
  
  destroy.success.wants.js { render_js_for_destroy }
end
