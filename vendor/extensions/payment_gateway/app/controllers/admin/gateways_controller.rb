class Admin::GatewaysController < Admin::BaseController
  
  index.response do |wants|
    configuration = GatewayConfiguration.find 1
    wants.html { redirect_to edit_admin_gateway_configuration_url(configuration) }
  end

end
