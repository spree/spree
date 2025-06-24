require 'spec_helper'

RSpec.describe 'Account gift cards', type: :feature do
  let(:user) { create(:user) }
  let!(:gift_card) { create(:gift_card, user: user, amount: 10.00, expires_at: 3.days.from_now) }

  before do
    login_as(user, scope: :user)
    visit spree.account_gift_cards_path
  end

  it 'shows gift cards' do
    within("#gift_card_#{gift_card.id}") do
      expect(page).to have_content(gift_card.display_code)
      expect(page).to have_content(gift_card.display_state.titleize)
      expect(page).to have_content(gift_card.display_amount)
      expect(page).to have_content(gift_card.display_amount_used)
      expect(page).to have_content(gift_card.expires_at.strftime('%B %-d, %Y'))
    end
  end
end
