class Admin::VariationsController < Admin::BaseController

  def new
    @variation = Variation.new
    render :layout => false
  end

  def create
    @product = Product.find(params[:id])
    variation = Variation.new
    variation.option = Option.find(params[:option_id])
    variation.option_value = OptionValue.find(params[:option_value_id])
    variation.product = @product
    logger.debug("product: " + variation.product.inspect)
    logger.debug("option_value: " + variation.option_value.inspect)
    
    variation.save!
    flash[:notice] = 'Variation was successfully created.'
    redirect_to :controller => 'products', :action => 'edit', :id => @product    
  rescue Exception => e
    logger.error("unable to create variation")
    logger.error("message: " + e.message)
    flash[:error] = ' Problem saving variation'
    redirect_to :controller => 'products', :action => 'edit', :id => @product
  end

  # delete the variation (ajax call from either product or category edit screen)
  def delete
    v = Variation.find(params[:id])
    if v.variable_type == "Product"
      @product = Product.find v.variable_id  
      @variations = @product.variations
    else
      @category = Category.find v.variable_id
      @variations = @category.variations
    end
    v.destroy
    render :update do |page|
      #page.replace_html 'variations', :partial => 'updated_template'
      page.replace_html 'variations', :partial => 'shared/variations', :locals => {:variations => @variations, :product => @product, :category => @category}
      #render :partial => 'shared/variations', :locals => {:variations => @product.variations, :product => @product, :category => @category}
    end
  end

  # AJAX method to show variations based on change in parent category (during category edit)
  def category_variations
    category = Category.find_or_create_by_id(params[:category_id])
    if (params[:parent_id].blank?)
      category.parent = Category.find(:first)
    else
      category.parent = Category.find(params[:parent_id])      
    end
    
    render  :partial => 'shared/variations',
            :locals => {:variations => category.variations, :category => category},
            :layout => false
  end

  # AJAX method to show variations based on change in category (during product edit)
  def product_variations
    product = Product.find_or_create_by_id(params[:product_id])
    if (params[:category_id].blank?)
      product.category = Category.find(:first)
    else
      product.category = Category.find(params[:category_id])      
    end
    
    render  :partial => 'shared/variations',
            :locals => {:variations => product.variations, :product => product},
            :layout => false
  end
  
end
