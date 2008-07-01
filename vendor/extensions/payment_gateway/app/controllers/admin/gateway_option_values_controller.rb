class Admin::GatewayOptionValuesController < Admin::BaseController
  resource_controller
  
  belongs_to :gateway_configuration

  index.before do
    chosen_gateway = Gateway.find(params[:gw_id])
    @option_values = @gateway_configuration.gateway_option_values
    unless @gateway_configuration.gateway == chosen_gateway
      # show a blank set of values for editing purposes (original values preserved in DB until user posts the update)
      @option_values = []
      chosen_gateway.gateway_options.each do |option|
        @option_values << GatewayOptionValue.new(:gateway_option => option)
      end
    end
  end
  
  index.response do |wants|
    wants.html { render :partial => "options", 
                        :layout => false, 
                        :locals => {:option_values => @option_values} }
  end
    
end