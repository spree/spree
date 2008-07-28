class Admin::GatewayConfigurationsController < Admin::BaseController
  resource_controller
  
  before_filter :load_data
    
  update.after do
    @gateway_configuration.gateway_option_values.clear
    if params[:option]
      params[:option].each do |key, value|
        GatewayOptionValue.create(:gateway_configuration => @gateway_configuration,
                                  :gateway_option_id => key,
                                  :value => value)
      end
    end
  end
  
  update.response do |wants|
    wants.html {redirect_to edit_object_url}
  end
    
  private
  
      def load_data
        @available_gateways = Gateway.find(:all, :order => :name)
      end  
end