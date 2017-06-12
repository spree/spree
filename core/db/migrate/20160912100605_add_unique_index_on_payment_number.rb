class AddUniqueIndexOnPaymentNumber < ActiveRecord::Migration[4.2]
  def change
    non_unique_number_payments = Spree::Payment.all.group("number").having("count(*) > ?", 1)
    non_unique_numbers = []
    non_unique_number_payments.each do |p|
      non_unique_numbers << p.number
    end

    payments_with_non_unique_numbers = Spree::Payment.where(number: non_unique_numbers)
    payments_with_non_unique_numbers.count.times do |i|
      p = payments_with_non_unique_numbers[i]
      p.number += i.to_s
      p.save
    end

    add_index :spree_payments, :number, unique: true
  end
end
