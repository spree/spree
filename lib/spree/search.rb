module Spree::Search
  def retrieve_products
    # taxon might be already set if this method is called from TaxonsController#show
    @taxon ||= Taxon.find_by_id(params[:taxon]) unless params[:taxon].blank?
    # add taxon id to params for searcher
    params[:taxon] = @taxon.id if @taxon
    @keywords = params[:keywords]
    
    per_page = params[:per_page].to_i
    per_page = per_page > 0 ? per_page : Spree::Config[:products_per_page]
    params[:per_page] = per_page
    params[:page] = 1 if (params[:page].to_i <= 0)
    
    # Prepare a search within the parameters
    Spree::Config.searcher.prepare(params)

    if !params[:order_by_price].blank?
      @product_group = ProductGroup.new.from_route([params[:order_by_price]+"_by_master_price"])
    elsif params[:product_group_name]
      @cached_product_group = ProductGroup.find_by_permalink(params[:product_group_name])
      @product_group = ProductGroup.new
    elsif params[:product_group_query]
      @product_group = ProductGroup.new.from_route(params[:product_group_query])
    else
      @product_group = ProductGroup.new
    end

    @product_group.add_scope('in_taxon', @taxon) unless @taxon.blank?
    @product_group.add_scope('keywords', @keywords) unless @keywords.blank?
    @product_group = @product_group.from_search(params[:search]) if params[:search]
    
    base_scope = Product.active
    #base_scope = @cached_product_group ? @cached_product_group.products.active : Product.active
    base_scope = base_scope.on_hand unless Spree::Config[:show_zero_stock_products]
    @products_scope = @product_group.apply_on(base_scope)

    curr_page = Spree::Config.searcher.manage_pagination ? 1 : params[:page]
    @products = @products_scope.all.paginate({
        :include  => [:images, :master],
        :per_page => per_page,
        :page     => curr_page
      })
    @products_count = @products_scope.count

    return(@products)
  end
end
