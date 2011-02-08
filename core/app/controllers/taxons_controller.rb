class TaxonsController < Spree::BaseController
  #prepend_before_filter :reject_unknown_object, :only => [:show]
  before_filter :load_data, :only => :show

  helper :products

  def show
  end

  private
  def load_data
    @taxon ||= Taxon.where(:permalink => params[:id]).first
    params[:taxon] = @taxon.id
    @searcher = Spree::Config.searcher_class.new(params)
    @products = @searcher.retrieve_products
  end

  def accurate_title
    @taxon ? @taxon.name : nil
  end
end
