class TaxonsController < Spree::BaseController

  helper :products
  rescue_from ActiveRecord::RecordNotFound, :with => :render_404

  def show
    raise ActiveRecord::RecordNotFound unless @taxon = Taxon.find_by_permalink(params[:id])
    params[:taxon] = @taxon.id
    @searcher = Spree::Config.searcher_class.new(params)
    @products = @searcher.retrieve_products
  end

  private

  def accurate_title
    @taxon ? @taxon.name : nil
  end

end
