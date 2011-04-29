class Admin::TaxonomiesController < Admin::ResourceController

  def get_children
    @taxons = Taxon.find(params[:parent_id]).children
  end
  
  private
  
  def location_after_save
    if @taxonomy.created_at == @taxonomy.updated_at
      edit_admin_taxonomy_path(@taxonomy)
    else
      admin_taxonomies_path
    end
  end
end
