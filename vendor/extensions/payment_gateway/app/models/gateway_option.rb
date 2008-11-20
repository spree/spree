class GatewayOption < ActiveRecord::Base
  belongs_to :gateway
  has_many :gateway_option_values, :dependent => :destroy
end
