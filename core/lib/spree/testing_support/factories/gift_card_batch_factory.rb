# == Schema Information
#
# Table name: spree_gift_card_batches
#
#  id                   :bigint           not null, primary key
#  amount               :decimal(10, 2)   default(10.0), not null
#  codes_count          :integer          default(1), not null
#  expires_at           :date
#  minimum_order_amount :decimal(10, 2)   default(0.0)
#  prefix               :string
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  tenant_id            :bigint           not null

FactoryBot.define do
  factory :gift_card_batch, class: Spree::GiftCardBatch do
    store { Spree::Store.default || create(:store) }
  end
end
