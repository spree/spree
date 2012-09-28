module Spree
  class TaxonsController < BaseController
    rescue_from ActiveRecord::RecordNotFound, :with => :render_404
    helper 'spree/products'

    respond_to :html

    def show
      @taxon = Taxon.find_by_permalink!(params[:id])
      return unless @taxon

      params[:user_id] = try_spree_current_user.id if try_spree_current_user
      @searcher = Spree::Config.searcher_class.new(params.merge(:taxon => @taxon.id))
      @products = @searcher.retrieve_products

      respond_with(@taxon)
    end

    private
      def accurate_title
        @taxon ? @taxon.name : super
      end
  end
end
