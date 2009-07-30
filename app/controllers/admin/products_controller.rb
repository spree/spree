class Admin::ProductsController < Admin::BaseController
  resource_controller
  before_filter :load_data

  # set the default tax_category if applicable
  new_action.before do
    next unless Spree::Config[:default_tax_category]
    @product.tax_category = TaxCategory.find_by_name Spree::Config[:default_tax_category]
  end
  
  new_action.response do |wants|
    wants.html {render :action => :new, :layout => false}
  end

  update.before do
    # note: we only reset the product properties if we're receiving a post from the form on that tab
    next unless params[:clear_product_properties] 
    params[:product] ||= {}
    params[:product][:product_property_attributes] ||= {} if params[:product][:product_property_attributes].nil?
  end

  create.response do |wants| 
    # go to edit form after creating as new product
    wants.html {redirect_to edit_admin_product_url(Product.find(@product.id)) }
  end

  update.response do |wants| 
    # override the default redirect behavior of r_c
    # need to reload Product in case name / permalink has changed
    wants.html {redirect_to edit_admin_product_url(Product.find(@product.id)) }
  end
  
  # override the destory method to set deleted_at value 
  # instead of actually deleting the product.
  def destroy
    @product = Product.find_by_permalink(params[:id])
    @product.deleted_at = Time.now()
    
    @product.variants.each do |v|   
      v.deleted_at = Time.now()
      v.save
    end
    
    if @product.save
      flash[:notice] = "Product has been deleted"
    else
      flash[:notice] = "Product could not be deleted"
    end
    
    redirect_to collection_url
  end
  
  private
    def load_data
      @tax_categories = TaxCategory.find(:all, :order=>"name")  
      @shipping_categories = ShippingCategory.find(:all, :order=>"name")  
    end
    
    def collection
      base_scope = end_of_association_chain

      # Note: the SL scopes are on/off switches, so we need to select "not_deleted" explicitly if the switch is off
      # QUERY - better as named scope or as SL scope?
      if params[:search].nil? || params[:search][:deleted_at_not_null].blank?
        base_scope = base_scope.not_deleted
      end

      @search = base_scope.search(params[:search])
      @search.order ||= "ascend_by_name"

      @collection = @search.paginate(:include  => {:variants => :images},
                                     :per_page => Spree::Config[:admin_products_per_page], 
                                     :page     => params[:page])
    end

    # override rc_default build b/c we need to make sure there's an empty variant added to each product
    def build_object
      @object ||= Product.new params[:product]      
      if @object.variants.empty?
        @object.available_on = Time.now
        @object.variants << Variant.new(:product => @object)
      end
      @object.variant.sku = params[:product] ? params[:product][:sku] : ""
      @object
    end   
  
end
