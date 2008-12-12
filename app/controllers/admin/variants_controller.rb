class Admin::VariantsController < Admin::BaseController
  resource_controller
  belongs_to :product

  new_action.response do |wants|
    wants.html {render :action => :new, :layout => false}
  end

  create.before do 
    option_values = params[:new_variant]
    option_values.each_value {|id| @object.option_values << OptionValue.find(id)}
    @object.save
  end
  
  # redirect to index (instead of r_c default of show view)
  create.response do |wants| 
    wants.html {redirect_to collection_url}
  end

  # redirect to index (instead of r_c default of show view)
  update.response do |wants| 
    wants.html {redirect_to collection_url}
  end
  
  # override the destory method to set deleted_at value 
  # instead of actually deleting the product.
  def destroy
    @variant = Variant.find(params[:id])
      
    @variant.deleted_at = Time.now()
    if @variant.save
      flash[:notice] = "Variant has been deleted"
    else
      flash[:notice] = "Variant could not be deleted"
    end
    
    redirect_to admin_product_variants_url(params[:product_id])
  end
  
  private 
  def collection
    @deleted =  (params.key?(:deleted)  && params[:deleted] == "on") ? "checked" : ""
    
    if @deleted.blank?
      @collection ||= end_of_association_chain.active.find(:all)
    else
      @collection ||= end_of_association_chain.deleted.find(:all)
    end
  end
end
