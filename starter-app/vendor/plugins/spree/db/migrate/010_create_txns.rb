class CreateTxns < ActiveRecord::Migration
  def self.up
	  create_table "txns", :force => true do |t|
	    t.column "credit_card_id", :integer
	    t.column "amount",        :decimal,  :precision => 8, :scale => 2, :default => 0.0, :null => false
	    t.column "txn_type",      :string
	    t.column "response_code", :string
	    t.column "avs_response",  :text
	    t.column "cvv_response",  :text
	    t.column "created_at",    :datetime
	    t.column "updated_at",    :datetime
	  end
  end

  def self.down
    drop_table "txns"
  end
end