class ResponseCodeAndAvsResponseForPayments < ActiveRecord::Migration
  def self.up
    add_column :payments, :response_code, :string
    add_column :payments, :avs_response, :string
  end

  def self.down
    remove_column :payments, :response_code
    remove_column :payments, :avs_response
  end
end
