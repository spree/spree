class CreateCreditcards < ActiveRecord::Migration
  def self.up
    create_table :creditcards, :force => true do |t|
      t.references :order
	    t.string :number
	    t.string :month
	    t.string :year
	    t.string :verification_value
	    t.string :cc_type
	    t.string :display_number
	    t.string :first_name
	    t.string :last_name
	    t.timestamps
	  end
  end

  def self.down
    drop_table :creditcards
  end
end
