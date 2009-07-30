class ProductsController < Spree::BaseController
  before_filter(:setup_admin_user) unless RAILS_ENV == "test"

  resource_controller
  helper :taxons  
  before_filter :load_data, :only => :show
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
  def setup_admin_user
    return if admin_created?
    flash[:notice] = I18n.t(:please_create_user)
    redirect_to signup_url
  end
  
  def load_data  
    load_object  
    @selected_variant = @product.variants.detect { |v| v.in_stock || Spree::Config[:allow_backorders] }
		
    return unless permalink = params[:taxon_path]
    @taxon = Taxon.find_by_permalink(params[:taxon_path].join("/") + "/")	 
  end
  
  def collection
    base_scope = Product.active

    if !params[:taxon].blank? && (@taxon = Taxon.find_by_id(params[:taxon]))
      taxon_and_descendants = [@taxon] + @taxon.descendents
      base_scope = base_scope.taxons_id_equals_any(taxon_and_descendants.map(&:id))
    end
                
    @search = base_scope.search(params[:search])

    # set on model basis (default 30)
    # Product.per_page ||= Spree::Config[:products_per_page]

    ## defunct?
    @product_cols = 3 

    @products ||= @search.paginate(:include  => [:images, {:variants => :images}],
                                   :per_page => Spree::Config[:products_per_page],
                                   :page     => params[:page])
  end
end
