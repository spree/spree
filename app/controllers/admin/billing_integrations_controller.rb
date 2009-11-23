class Admin::BillingIntegrationsController < Admin::BaseController
  resource_controller
  before_filter :load_data

  update.before :update_before

  update.wants.html { redirect_to edit_object_url }
  create.wants.html { redirect_to edit_object_url }
  destroy.success.wants.js { render_js_for_destroy }

  private       
  def build_object
		if params[:billing_integration] && params[:billing_integration][:type]
			@object ||= params[:billing_integration][:type].constantize.send parent? ? :build : :new, object_params 
		else
			@object ||= end_of_association_chain.send parent? ? :build : :new, object_params 
		end
  end
  
  def load_data   
    @providers = BillingIntegration.providers
  end
  
  def update_before 
		if params[:billing_integration] && params[:billing_integration][:type] && @object.type.to_s != params[:billing_integration][:type]
			@object.type = params[:billing_integration][:type]
			@object.save
			
			load_object			
		end
 		@object.update_attributes params[@object.class.name.underscore.gsub("/", "_")]
  end
  
end
