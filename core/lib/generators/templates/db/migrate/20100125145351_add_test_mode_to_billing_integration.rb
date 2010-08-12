class AddTestModeToBillingIntegration < ActiveRecord::Migration
  def self.up
    add_column :billing_integrations, :test_mode, :boolean, :default => true
    add_column :billing_integrations, :server, :string, :default => "test"
  end

  def self.down
    remove_column :billing_integrations, :test_mode
    remove_column :billing_integrations, :server
  end
end
