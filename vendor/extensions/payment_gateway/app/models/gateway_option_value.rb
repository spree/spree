class GatewayOptionValue < ActiveRecord::Base
  belongs_to :gateway_option
  belongs_to :gateway_configuration
end
