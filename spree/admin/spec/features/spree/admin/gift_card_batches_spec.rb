require 'spec_helper'

RSpec.describe 'Gift Card Batches', type: :feature do
  stub_authorization!

  let(:store) { @default_store }
  let(:store_gift_card_batches) { Spree::GiftCardBatch.for_store(store) }

  scenario 'admin creates a new gift card batch' do
    visit spree.new_admin_gift_card_batch_path

    fill_in 'Prefix', with: 'TEST-GC'
    fill_in 'Amount', with: 5
    fill_in 'Codes count', with: 5

    click_on 'Create'

    expect(page).to have_content('Gift card batch has been successfully created!')
    expect(page).to have_current_path(spree.admin_gift_cards_path(q: { batch_prefix_eq: 'TEST-GC' }))

    expect(store_gift_card_batches.count).to eq(1)
    expect(store_gift_card_batches.first.prefix).to eq('TEST-GC')
    expect(store_gift_card_batches.first.amount).to eq(5)
    expect(store_gift_card_batches.first.codes_count).to eq(5)

    store_gift_card_batches.first.gift_cards.each do |gift_card|
      expect(page).to have_content(gift_card.code.upcase)
    end
  end
end
