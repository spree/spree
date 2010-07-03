class Admin::PromotionRulesController < Admin::BaseController
  resource_controller         
  belongs_to :promotion
  
  create.response do |wants| 
    wants.html { redirect_to edit_admin_promotion_path(parent_object) }
    wants.js { render :action => 'create', :layout => false}
  end
  destroy.response do |wants| 
    wants.html { redirect_to edit_admin_promotion_path(parent_object) }
    wants.js { render :action => 'destroy', :layout => false}
  end

  private
  
    def build_object
      return @object if @object.present?
  		if params[:promotion_rule] && params[:promotion_rule][:type]
  			@object = params[:promotion_rule][:type].constantize.new(object_params) 
  			@object.promotion = parent_object
  		else
  			@object = end_of_association_chain.build(object_params)
  		end
  		@object
    end
  
end
