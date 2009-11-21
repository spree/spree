module Spree::Search
  def retrieve_products
    # taxon might be already set if this method is called from TaxonsController#show
    @taxon ||= params[:taxon] && Taxon.find_by_id(params[:taxon])
    # add taxon id to params for searcher
    params[:taxon] = @taxon.id if @taxon
    @keywords = params[:keywords]
    per_page = params[:per_page] || Spree::Config[:products_per_page]
    params[:per_page] = per_page
    curr_page = Spree::Config.searcher.manage_pagination ? 1 : params[:page]
    # Prepare a search within the parameters
    Spree::Config.searcher.prepare(params)

    if params[:product_group_name]
      @product_group = ProductGroup.find_by_permalink(params[:product_group_name])
    elsif params[:product_group_query]
      @product_group = ProductGroup.new.from_route(params[:product_group_query])
    else
      @product_group = ProductGroup.new
    end

    @product_group.add_scope('in_taxon', @taxon) unless @taxon.blank?
    @product_group.add_scope('keywords', @keywords) unless @keywords.blank?
    @product_group = @product_group.from_search(params[:search]) if params[:search]
    
    params[:search] = @product_group.scopes_to_hash if @keywords.blank?

    base_scope = Spree::Config[:allow_backorders] ? Product.active : Product.active.on_hand
    @products_scope = @product_group.apply_on(base_scope)

    @products = @products_scope.paginate({
        :include  => [:images, :master],
        :per_page => per_page,
        :page     => curr_page
      })
    @products_count = @products_scope.count

    return(@products)
  end
end
