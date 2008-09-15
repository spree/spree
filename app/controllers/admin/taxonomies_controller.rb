class Admin::TaxonomiesController < Admin::BaseController
  resource_controller
  
  edit.response do |wants|
    wants.html
    wants.js do
      render :partial => 'edit.html.erb'
    end
  end

 
end
