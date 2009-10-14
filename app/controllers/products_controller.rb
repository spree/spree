class ProductsController < Spree::BaseController
  prepend_before_filter :reject_unknown_object, :only => [:show]
  before_filter :load_data, :only => :show

  resource_controller
  helper :taxons  
  actions :show, :index

  index do
    before do
      @product_cols = 3
    end
  end

  def change_image
    @product = Product.available.find_by_param(params[:id])
    img = Image.find(params[:image_id])
    render :partial => 'image', :locals => {:image => img}
  end

  private
  def load_data  
    load_object  
    @selected_variant = @product.variants.detect { |v| v.available? }
		
    return unless permalink = params[:taxon_path]
    @taxon = Taxon.find_by_permalink(params[:taxon_path].join("/") + "/")	 
  end
  
  def collection
    @search = Product.active

    if !params[:taxon].blank? && (@taxon = Taxon.find_by_id(params[:taxon]))
      @search = @search.taxons_id_in_tree(@taxon)
    end
    
    # Define what is allowed.
    sort_params = {
      "price_asc"  => ["variants_price", "asc"],
      "price_desc" => ["variants_price", "desc"],
      "date_asc"   => ["available_on", "asc"],
      "date_desc"  => ["available_on", "desc"],
      "name_asc"   => ["name", "asc"],
      "name_desc"  => ["name", "desc"]
    }
    # Set it to what is allowed or default.
    sort_by_and_as = sort_params[params[:sort]] || sort_params['date_desc']
    

    @search = @search.send "#{sort_by_and_as[1]}end_by_#{sort_by_and_as[0]}" if sort_by_and_as
    @search = @search.query(params[:keywords].to_s) unless params[:keywords].blank?
    @search = @search.search(params[:search]) unless params[:search].blank?  

    # this can now be set on a model basis 
    # Product.per_page ||= Spree::Config[:products_per_page]
    per_page = params[:per_page].present? ? params[:per_page] : Spree::Config[:products_per_page]
       
    ## defunct?
    @product_cols = 3

    @products_count = @search.count
    @products ||= @search.paginate(:include  => [:images, {:variants => :images}],
                                  :per_page => per_page,
                                  :page     => params[:page])    
  end
end
