class Admin::ProductsController < Admin::BaseController
  resource_controller
  before_filter :load_data
  after_filter :set_image, :only => [:create, :update]

  update.before do
    # note: we only reset the product properties if we're receiving a post from the form on that tab
    next unless params[:clear_product_properties] 
    params[:product] ||= {}
    params[:product][:product_property_attributes] ||= {} if params[:product][:product_property_attributes].nil?
  end

  update.response do |wants| 
    # override the default redirect behavior of r_c
    wants.html {redirect_to edit_object_url}
  end
  
  private
    def load_data
      @tax_categories = TaxCategory.find(:all, :order=>"name")  
      @shipping_categories = ShippingCategory.find(:all, :order=>"name")  
    end

    def set_image
      return unless params[:image]
      return if params[:image][:uploaded_data].blank?    
      image = Image.create params[:image] if params[:image]
      object.images << image
    end
    
    def collection
      @name = params[:name] || ""
      @sku = params[:sku] || ""
      if @sku.blank?
        @collection ||= end_of_association_chain.by_name(@name).find(:all, :order => :name, :page => {:start => 1, :size => 10, :current => params[:p]})
      else
        @collection ||= end_of_association_chain.by_name(@name).by_sku(@sku).find(:all, :order => :name, :page => {:start => 1, :size => 10, :current => params[:p]})
      end
    end

    # override rc_default build b/c we need to make sure there's an empty variant added to each product
    def build_object
      @object ||= Product.new params[:product]      
      if @object.variants.empty?
        @object.available_on = Time.now
        @object.variants << Variant.new(:product => @object)
      end
      @object
    end    
end
