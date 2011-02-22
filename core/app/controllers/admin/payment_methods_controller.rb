class Admin::PaymentMethodsController < Admin::BaseController
  resource_controller
  before_filter :load_providers

  update.before :update_before

  update.wants.html { redirect_to edit_object_url }
  create.wants.html { redirect_to edit_object_url }

  def index
    @payment_methods = PaymentMethod.order('name')
  end


  private

  def build_object
		if params[:payment_method] && params[:payment_method][:type]
			@object ||= params[:payment_method][:type].constantize.send parent? ? :build : :new, object_params
		else
			@object ||= end_of_association_chain.send parent? ? :build : :new, object_params
		end
  end

  def load_providers
    @providers = Gateway.providers
  end

  def update_before
		if params[:payment_method] && params[:payment_method][:type] && @object['type'].to_s != params[:payment_method][:type]
			@object.update_attribute(:type, params[:payment_method][:type])

			load_object
		end
 		@object.update_attributes params[@object.class.name.underscore.gsub("/", "_")]
  end
end
