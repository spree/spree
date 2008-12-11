class Admin::ProductsController < Admin::BaseController
  resource_controller
  before_filter :load_data
  after_filter :set_image, :only => [:create, :update]

  # set the default tax_category if applicable
  new_action.before do
    next unless Spree::Config[:default_tax_category]
    @product.tax_category = TaxCategory.find_by_name Spree::Config[:default_tax_category]
  end
  
  update.before do
    # note: we only reset the product properties if we're receiving a post from the form on that tab
    next unless params[:clear_product_properties] 
    params[:product] ||= {}
    params[:product][:product_property_attributes] ||= {} if params[:product][:product_property_attributes].nil?
  end

  update.response do |wants| 
    # override the default redirect behavior of r_c
    # need to reload Product in case name / permalink has changed
    wants.html {redirect_to edit_admin_product_url Product.find(@product.id) }
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

    def set_image
      return unless params[:image]
      return if params[:image][:attachment].blank?    
      image = Image.create params[:image] if params[:image]
      object.images << image
    end
    
    def collection
      @name = params[:name] || ""
      @sku = params[:sku] || ""
      @deleted =  (params.key?(:deleted)  && params[:deleted] == "on") ? "checked" : ""
      
      if @sku.blank?
        if @deleted.blank?
          @collection ||= end_of_association_chain.active.by_name(@name).find(:all, :order => :name, :page => {:start => 1, :size => Spree::Config[:admin_products_per_page], :current => params[:p]})
        else
          @collection ||= end_of_association_chain.deleted.by_name(@name).find(:all, :order => :name, :page => {:start => 1, :size => Spree::Config[:admin_products_per_page], :current => params[:p]})  
        end
      else
        if @deleted.blank?
          @collection ||= end_of_association_chain.active.by_name(@name).by_sku(@sku).find(:all, :order => :name, :page => {:start => 1, :size => Spree::Config[:admin_products_per_page], :current => params[:p]})
        else
          @collection ||= end_of_association_chain.deleted.by_name(@name).by_sku(@sku).find(:all, :order => :name, :page => {:start => 1, :size => Spree::Config[:admin_products_per_page], :current => params[:p]})
        end
      end
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
