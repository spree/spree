class Admin::TaxonsController < Admin::BaseController
  resource_controller
  
  before_filter :load_object, :only => [:selected, :available, :remove]
  belongs_to :product
  
  create.wants.html {redirect_to edit_admin_taxonomy_path(@taxon.taxonomy)}
  update.wants.html {redirect_to edit_admin_taxonomy_path(@taxon.taxonomy)}
  destroy.wants.js {render :text => ""}
  
  create.before do 
    @taxon.taxonomy_id = params[:taxonomy_id]
    @taxon.position = Taxon.find(@taxon.parent_id).children.length + 1
  end
    
  def selected 
    @taxons = @product.taxons
  end
  
  def available
    if params[:q].blank?
      @available_taxons = []
    else
      @available_taxons = Taxon.find(:all, :conditions => ['lower(presentation) LIKE ?', "%#{params[:q].downcase}%"])
    end
    @available_taxons.delete_if { |taxon| @product.taxons.include?(taxon) }
    respond_to do |format|
      format.html
      format.js {render :layout => false}
    end
    #@available_taxons = Taxon.all #hack
    #
  end
  
  def remove
    @product.taxons.delete(@taxon)
    @product.save
    @taxons = @product.taxons
    render :layout => false
  end  
  
  def select
    @product = Product.find_by_param!(params[:product_id])
    taxon = Taxon.find(params[:id])
    @product.taxons << taxon
    @product.save
    @taxons = @product.taxons
    render :layout => false
  end
  
  private 
  
end