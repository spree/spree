# == Schema Information
#
# Table name: spree_gift_cards
#
#  id                   :bigint           not null, primary key
#  amount               :decimal(10, 2)   not null
#  amount_remaining     :decimal(10, 2)   default(0.0), not null
#  code                 :string           not null
#  expires_at           :date
#  minimum_order_amount :decimal(10, 2)   default(0.0)
#  state                :integer          default(0), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  gift_card_batch_id   :bigint
#  store_credit_id      :bigint
#  store_id             :bigint           not null
#  tenant_id            :bigint           not null
#  user_id              :bigint
#
FactoryBot.define do
  factory :gift_card, class: Spree::GiftCard do
    state { :active }
    amount { 10.00 }
    store { Spree::Store.default || create(:store) }

    trait :fully_redeemed do
      state { :redeemed }
    end
  end
end
