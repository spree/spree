class Admin::TaxonsController < Admin::BaseController
  resource_controller
  
  before_filter :load_object, :only => [:selected, :available, :remove]
  belongs_to :product
  
  def selected 
    @taxons = @product.taxons
  end
  
  def available
    @available_taxons = Taxon.find(:all, :conditions => ['lower(presentation) LIKE ?', "%#{params[:q].downcase}%"])
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
    flash[:notice] = "Succesfully removed taxon."
    redirect_to selected_admin_product_taxons_url(@product)
  end  
  
  def select
    @product = Product.find_by_param!(params[:product_id])
    taxon = Taxon.find(params[:id])
    @product.taxons << taxon
    @product.save
    @taxons = @product.taxons
    render :action => :selected, :layout => false
  end
  
  private 
  
end