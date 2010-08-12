class MoveToConfigurableGateways < ActiveRecord::Migration
  def self.up
    drop_table :gateways
    drop_table :gateway_options
    drop_table :gateway_option_values
    drop_table :gateway_configurations

    create_table :gateways, :force => true do |t|
      t.string :type
      t.string :name
      t.text :description
      t.boolean :active, :default => true
      t.string :environment, :default => "development"
      t.string :server, :default => "test"
      t.boolean :test_mode, :default => true
      t.timestamps
    end
  end

  def self.down
    drop_table :gateways
    create_table "gateway_configurations", :force => true do |t|
      t.integer  "gateway_id"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    create_table "gateway_option_values", :force => true do |t|
      t.integer  "gateway_configuration_id"
      t.integer  "gateway_option_id"
      t.text     "value"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    create_table "gateway_options", :force => true do |t|
      t.string   "name"
      t.text     "description"
      t.integer  "gateway_id"
      t.boolean  "textarea",    :default => false
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    create_table "gateways", :force => true do |t|
      t.string   "clazz"
      t.string   "name"
      t.text     "description"
      t.boolean  "active"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

  end
end
