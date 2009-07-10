class Admin::ImagesController < Admin::BaseController
  resource_controller
  before_filter :load_data, :except => :create
	belongs_to :variant, :product
	
	new_action.response do |wants|
    wants.html {render :action => :new, :layout => false}
  end

	create.response do |wants|
		wants.html {redirect_to admin_product_images_url(@product)}
  end
	
	create.before do
		if params.has_key? :viewable_id
			if params[:viewable_id] == "All"
				object.viewable_type = 'Product'
			else
				object.viewable_type = 'Variant'
				object.viewable_id = params[:viewable_id]
			end
		end
	end
	
  destroy.before do 
    @viewable = object.viewable
  end
  
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
		
		@variants.insert(0, "All")
  end


end
