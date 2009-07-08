class ProductsController < Spree::BaseController
  before_filter :setup_admin_user

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
    return unless permalink = params[:taxon_path]
    @taxon = Taxon.find_by_permalink(params[:taxon_path].join("/") + "/")
  end
  
  def collection
    if params[:taxon]
      @taxon = Taxon.find(params[:taxon])
      
      @search = Product.active.scoped(:conditions =>
                                        ["products.id in (select product_id from products_taxons where taxon_id in (" +
                                          @taxon.descendents.inject( @taxon.id.to_s) { |clause, t| clause += ', ' + t.id.to_s} + "))"
                                        ]).new_search(params[:search])
    else
      @search = Product.active.new_search(params[:search])
    end

    @search.per_page = Spree::Config[:products_per_page]
    @search.include = :images

    @product_cols = 3
    @products ||= @search.all
  end
end
