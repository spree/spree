class EnsurePaymentsHaveNumbers < ActiveRecord::Migration
  def change
    Spree::Payment.where(number: nil).find_each do |payment|
      payment.generate_number
      payment.update_columns(number: payment.number)
    end
  end
end
