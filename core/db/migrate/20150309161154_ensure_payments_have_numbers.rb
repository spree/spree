class EnsurePaymentsHaveNumbers < ActiveRecord::Migration[4.2]
  def change
    add_index :spree_payments, :number unless index_exists?(:spree_payments, :number)
    Spree::Payment.where(number: nil).find_each do |payment|
      begin
        payment.save! # to generate a new number we need to save the record
      rescue ActiveRecord::RecordNotSaved
        Rails.logger.error("Payment with ID = #{payment.id} couldn't be saved")
        Rails.logger.error(payment.errors.full_messages.to_sentence)
      end
    end
  end
end
