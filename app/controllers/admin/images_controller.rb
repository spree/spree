class Admin::ImagesController < Admin::BaseController
  resource_controller
  before_filter :load_data
	belongs_to :variant
	
	new_action.response do |wants|
    wants.html {render :action => :new, :layout => false}
  end

	create.response do |wants|
		wants.html {redirect_to admin_product_images_url(@product)}
  end
	
  destroy.before do 
    @viewable = object.viewable
  end
  
  destroy.response do |wants| 
    wants.html do
      flash[:notice] = nil
			render :view => "index"
    end
  end
 
  private
  def load_data
		@product = Product.find_by_permalink(params[:product_id])
		@variants = @product.variants.collect do |variant| 
			[variant.options_text, variant.id ]
		end
		@variants.reject! { |v| v[0] == ""}
  end


end
