class Admin::ImagesController < Admin::BaseController
  resource_controller
  before_filter :load_data
  
  new_action.response do |wants|
    wants.html {render :action => :new, :layout => false}
  end

  create.response do |wants|
    wants.html {redirect_to admin_product_images_url(@product)}
  end

  update.response do |wants|
    wants.html {redirect_to admin_product_images_url(@product)}
  end
  
  create.before :set_viewable
  update.before :set_viewable
  destroy.before :destroy_before
  
  destroy.response do |wants| 
    wants.html do
      render :text => ""
    end
  end
 
  private

  def load_data
    @product = Product.find_by_permalink(params[:product_id])
    @variants = @product.variants.collect do |variant| 
      [variant.options_text, variant.id ]
    end
    @variants.insert(0, [I18n.t("all"), "All"])
  end

  def set_viewable
    if params[:image].has_key? :viewable_id
      if params[:image][:viewable_id] == "All"
        object.viewable = @product
      else
        object.viewable_type = 'Variant'
        object.viewable_id = params[:image][:viewable_id]
      end
    else
      object.viewable = @product
    end
  end
  
  def destroy_before 
    @viewable = object.viewable
  end

end
