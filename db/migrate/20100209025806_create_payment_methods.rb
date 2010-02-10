class CreatePaymentMethods < ActiveRecord::Migration
  def self.up  
    create_table :payment_methods do |t|
      t.string :type
      t.string :name
      t.text :description
      t.boolean :active, :default => true
      t.string :environment, :default => "development"
      t.timestamps
    end
    # TODO - also migrate any legacy configurations for gateways and billing integrations before dropping the old tables 
    # we probably also need to do this inside the payment_gateway extension b/c table won't exist yet in fresh bootstrap
    #drop_table :billing_integrations
    #drop_table :gateways 
  end

  def self.down
    drop_table :payment_methods
  end
end
