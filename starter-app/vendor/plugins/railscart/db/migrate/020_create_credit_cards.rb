class CreateCreditCards < ActiveRecord::Migration
  def self.up
    create_table :credit_cards do |t|
      t.integer :order_id
      t.string :number # IMPORTANT: Should be encrypted with the private key stored on a separate physical machine
      t.string :verification_value # IMPORTANT: Should be encrypted with the private key stored on a separate physical machine
      t.string :cc_type
      t.string :month
      t.string :year
      t.string :display_number
      t.string :first_name
      t.string :last_name
      t.timestamps
    end
  end

  def self.down
    drop_table :credit_cards
  end
end