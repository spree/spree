require 'spec_helper'
RSpec.describe 'Account store credits', type: :feature do
  let(:user) { create(:user) }
  let!(:store_credit) { create(:store_credit, user: user, amount: 100.00) }
  let!(:capture_event) do
    create(
      :store_credit_auth_event,
      store_credit: store_credit,
      amount: 10.00,
      action: Spree::StoreCredit::CAPTURE_ACTION
    )
  end

  before do
    login_as(user, scope: :user)
    visit spree.account_store_credits_path
  end

  it 'displays store credit history' do
    expect(page).to have_content(Spree.t(:store_credits))
    expect(page).to have_content(Spree.t('storefront.account.store_credits_history'))

    create_event = store_credit.store_credit_events.first

    within("#store_credit_event_#{create_event.id}") do
      expect(page).to have_content(create_event.created_at.strftime('%B %-d, %Y'))
      expect(page).to have_content(create_event.display_amount)
      expect(page).to have_content(create_event.display_action)
      expect(page).to have_content(create_event.display_user_total_amount)
    end

    within("#store_credit_event_#{capture_event.id}") do
      expect(page).to have_content(capture_event.created_at.strftime('%B %-d, %Y'))
      expect(page).to have_content(capture_event.display_amount)
      expect(page).to have_content(capture_event.display_action)
      expect(page).to have_content(capture_event.display_user_total_amount)
    end
  end
end
