class ResponseCodeAndAvsResponseForPayments < ActiveRecord::Migration
  def change
    add_column :payments, :response_code, :string
    add_column :payments, :avs_response, :string
  end
end
