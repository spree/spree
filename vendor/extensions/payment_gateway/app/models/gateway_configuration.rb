class GatewayConfiguration < ActiveRecord::Base
  belongs_to :gateway
  has_many :gateway_option_values, :dependent => :destroy
end