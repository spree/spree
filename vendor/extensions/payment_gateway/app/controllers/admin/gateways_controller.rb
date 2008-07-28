class Admin::GatewaysController < Admin::BaseController
  resource_controller
  
  index.response do |wants|
    configuration = GatewayConfiguration.find 1
    wants.html { redirect_to edit_admin_gateway_configuration_url(configuration) }
  end

end
