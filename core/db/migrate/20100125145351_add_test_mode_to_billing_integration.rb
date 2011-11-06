class AddTestModeToBillingIntegration < ActiveRecord::Migration
  def change
    add_column :billing_integrations, :test_mode, :boolean, :default => true
    add_column :billing_integrations, :server, :string, :default => 'test'
  end
end
