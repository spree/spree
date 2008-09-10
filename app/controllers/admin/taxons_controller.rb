class Admin::TaxonsController < Admin::BaseController
  resource_controller
  
  before_filter :load_object, :only => [:selected, :available, :remove]
  belongs_to :product
  
  def selected 
    @taxons = @product.taxons
  end
  
  def remove
    @product.taxons.delete(@taxon)
    @product.save
    flash[:notice] = "Succesfully removed taxon."
    redirect_to selected_admin_product_taxons_url(@product)
  end  
end