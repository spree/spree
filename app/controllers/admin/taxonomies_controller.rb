class Admin::TaxonomiesController < Admin::BaseController
  resource_controller
  
  update.wants.html {redirect_to collection_url}
  
  update.after do
    taxon = @taxonomy.taxons.find_by_parent_id(nil)
    taxon.name = @taxonomy.name
    taxon.presentation = @taxonomy.presentation
    taxon.save
  end
  
  edit.response do |wants|
    wants.html
    wants.js do
      render :partial => 'edit.html.erb'
    end
  end

 
end
