class MoveToConfigurableGateways < ActiveRecord::Migration
  def up
    drop_table :gateways
    drop_table :gateway_options
    drop_table :gateway_option_values
    drop_table :gateway_configurations

    create_table :gateways, :force => true do |t|
      t.string   :type, :name
      t.text     :description
      t.boolean  :active, :default => true
      t.string   :environment, :default => 'development'
      t.string   :server, :default => 'test'
      t.boolean  :test_mode, :default => true

      t.timestamps
    end
  end

  def down
    drop_table :gateways

    create_table :gateway_configurations, :force => true do |t|
      t.references :gateway

      t.timestamps
    end

    create_table :gateway_option_values, :force => true do |t|
      t.text     :value
      t.references :gateway_configuration
      t.references :gateway_option

      t.timestamps
    end

    create_table :gateway_options, :force => true do |t|
      t.string   :name
      t.text     :description
      t.boolean  :textarea, :default => false
      t.references :gateway

      t.timestamps
    end

    create_table :gateways, :force => true do |t|
      t.string   :clazz, :name
      t.text     :description
      t.boolean  :active

      t.timestamps
    end
  end
end
