class DropBillingIntegrations < ActiveRecord::Migration
  def self.up
    drop_table :billing_integrations
  end

  def self.down
    create_table :billing_integrations do |t|
      t.string :type, :name
      t.text :description
      t.boolean :active, :default => true
      t.string :environment, :default => 'development'

      t.timestamps
    end
  end
end
