class EnsurePaymentsHaveNumbers < ActiveRecord::Migration
  def change
    Spree::Payment.where(number: nil).find_each do |payment|
      payment.generate_number
      payment.save
    end
  end
end
