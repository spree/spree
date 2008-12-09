class CreatePaymentsTable < ActiveRecord::Migration
  def self.up
    rename_table :creditcard_payments, :payments
    change_table :payments do |t|
      t.decimal :amount, :precision => 8, :scale => 2, :default => 0.0, :null => false
      t.references :creditcard
      t.string :type
    end
    
    execute "UPDATE payments SET type = 'CreditcardPayment'"

    # create creditcard records for each of the existing creditcard payments
    Payment.all.each do |payment|
      creditcard = Creditcard.new
      %w{month year cc_type display_number first_name last_name number}.each do |name|
        creditcard[name] = payment[name]
      end
      # also move the address to the creditcard (no longer associated with the payment)
      creditcard.address = Address.find :first, :conditions => ["addressable_type = 'CreditcardPayment' AND addressable_id = ?", payment.id]
      creditcard.order = payment.order
      creditcard.save
      payment.amount = payment.order.total
      payment.creditcard = creditcard
      payment.save
    end

    change_table :payments do |t|
      t.remove :cc_type
      t.remove :display_number
      t.remove :first_name
      t.remove :last_name
      t.remove :number
      t.remove :month
      t.remove :year
    end

  end

  def self.down
    # no going back!
  end
end
