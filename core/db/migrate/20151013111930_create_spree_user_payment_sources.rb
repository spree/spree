class CreateSpreeUserPaymentSources < ActiveRecord::Migration
  def change
    create_table :spree_user_payment_sources do |t|
      t.references :user, index: true, foreign_key: false
      t.references :payment_source,
                   polymorphic: true,
                   index: { name: "index_users_payment_sources" }
      t.boolean :default

      t.timestamps null: false
    end

    Spree::CreditCard.find_each do |credit_card|
      Spree::UserPaymentSource.create(
        user_id: credit_card.user_id,
        payment_source_id: credit_card.id,
        payment_source_class: "Spree::CreditCard"
      )
    end
  end
end
