class Admin::PaymentMethodsController < Admin::ResourceController
  skip_load_resource :only => [:create]
  before_filter :load_data

  def create
    @payment_method = params[:payment_method][:type].constantize.new(params[:payment_method])
    @object = @payment_method
    invoke_callbacks(:create, :before)
    if @payment_method.save
      invoke_callbacks(:create, :after)
      flash[:notice] = I18n.t(:successfully_created, :resource => I18n.t(:payment_method))
      respond_with(@payment_method, :location => edit_admin_payment_method_path(@payment_method))
    else
      render :new
    end
  end

  def update
    invoke_callbacks(:update, :before)
    if @payment_method['type'].to_s != params[:payment_method][:type]
      @payment_method.update_attribute(:type, params[:payment_method][:type])
      @payment_method = PaymentMethod.find(params[:id])
    end
    if @payment_method.update_attributes params[@payment_method.class.name.underscore.gsub("/", "_")]
      invoke_callbacks(:update, :after)
      flash[:notice] = I18n.t(:successfully_updated, :resource => I18n.t(:payment_method))
      respond_with(@payment_method, :location => edit_admin_payment_method_path(@payment_method))
    else
      render :edit
    end
  end

  private

  def load_data
    @providers = Gateway.providers.sort{|p1, p2| p1.name <=> p2.name }
  end
end
