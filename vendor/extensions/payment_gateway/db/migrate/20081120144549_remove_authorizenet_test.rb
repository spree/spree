class RemoveAuthorizenetTest < ActiveRecord::Migration
  def self.up
    gateway = Gateway.find_by_name "Authorize.net"
    gateway_option = gateway.gateway_options.find_by_name "test"
    gateway_option.destroy
  end

  def self.down
  end
end