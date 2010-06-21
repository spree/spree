class Admin::TaxonomiesController < Admin::BaseController
  resource_controller
  
  create.wants.html {redirect_to edit_admin_taxonomy_url(@taxonomy)}
  update.wants.html {redirect_to collection_url}
  
  edit.response do |wants|
    wants.html
    wants.js do
      render :partial => 'edit.html.erb'
    end
  end
  
  def get_children
    @taxons = Taxon.find(params[:parent_id]).children
  end
end
