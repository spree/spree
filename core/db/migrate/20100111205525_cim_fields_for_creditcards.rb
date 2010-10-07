class CimFieldsForCreditcards < ActiveRecord::Migration
  def self.up
    add_column "creditcards", "gateway_customer_profile_id", :string
    add_column "creditcards", "gateway_payment_profile_id", :string
  end

  def self.down
    remove_column "creditcards", "gateway_customer_profile_id"
    remove_column "creditcards", "gateway_payment_profile_id"
  end
end
