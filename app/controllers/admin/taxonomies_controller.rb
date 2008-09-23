class Admin::TaxonomiesController < Admin::BaseController
  resource_controller
  
  create.wants.html {redirect_to edit_admin_taxonomy_url(@taxonomy)}
  update.wants.html {redirect_to collection_url}
  
  create.after do
    taxon = Taxon.new(:name => @taxonomy.name, :taxonomy_id => @taxonomy.id, :position => 1 )
    taxon.save
  end
  
  update.after do
    taxon = @taxonomy.taxons.find_by_parent_id(nil)
    taxon.name = @taxonomy.name
    taxon.save
  end
  
  edit.response do |wants|
    wants.html
    wants.js do
      render :partial => 'edit.html.erb'
    end
  end

 
end
