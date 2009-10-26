class ProductsController < Spree::BaseController
  HTTP_REFERER_REGEXP = /^https?:\/\/[^\/]+\/t\/([a-z0-9\-\/]+\/)$/

  prepend_before_filter :reject_unknown_object, :only => [:show]
  before_filter :load_data, :only => :show

  resource_controller
  helper :taxons
  actions :show, :index

  include Spree::Search

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

    referer = request.env['HTTP_REFERER']

    if referer  && referer.match(HTTP_REFERER_REGEXP)
      @taxon = Taxon.find_by_permalink($1)
    end
  end

  def collection
    retrieve_products
  end
end
