require 'spec_helper'

describe 'Store credits admin', type: :feature do
  stub_authorization!

  let!(:admin_user) { create(:admin_user) }
  let!(:store_credit) { create(:store_credit) }

  before do
    allow(Spree.user_class).to receive(:find_by).and_return(store_credit.user)
  end

  describe 'visiting the store credits page' do
    before do
      visit spree.admin_path
      click_link 'Users'
    end

    it 'is on the store credits page' do
      click_link store_credit.user.email
      click_link 'Store Credits'
      expect(page).to have_current_path(spree.admin_user_store_credits_path(store_credit.user))

      store_credit_table = page.find('table', match: :first)
      expect(store_credit_table).to have_css('tr').once
      expect(store_credit_table).to have_content(Spree::Money.new(store_credit.amount, currency: store_credit.currency).to_s)
      expect(store_credit_table).to have_content(Spree::Money.new(store_credit.amount_used, currency: store_credit.currency).to_s)
      expect(store_credit_table).to have_content(store_credit.category_name)
      expect(store_credit_table).to have_content(store_credit.created_by_email)
    end
  end

  describe 'creating store credit' do
    before do
      visit spree.admin_path
      click_link 'Users'
      click_link store_credit.user.email
      click_link 'Store Credits'
      allow_any_instance_of(Spree::Admin::StoreCreditsController).to receive(:try_spree_current_user).and_return(admin_user)
    end

    describe 'with default currency' do
      it 'creates store credit and associate it with the user' do
        click_link 'Add Store Credit'
        page.fill_in 'store_credit_amount', with: '102.00'
        select 'Exchange', from: 'store_credit_category_id'
        click_button 'Create'

        expect(page).to have_current_path(spree.admin_user_store_credits_path(store_credit.user))

        store_credit_table = page.find('table', match: :first)
        expect(store_credit_table).to have_css('tr').twice
        expect(Spree::StoreCredit.count).to eq 2
      end
    end

    describe 'with selected currency' do
      it 'creates store credit and associate it with the user' do
        click_link 'Add Store Credit'
        page.fill_in 'store_credit_amount', with: '100.00'
        select 'EUR', from: 'store_credit_currency'
        select 'Exchange', from: 'store_credit_category_id'
        click_button 'Create'

        expect(page).to have_current_path(spree.admin_user_store_credits_path(store_credit.user))

        store_credit_table = page.find('table', match: :first)
        expect(store_credit_table).to have_css('tr').twice
        expect(Spree::StoreCredit.count).to eq 2
        expect(Spree::StoreCredit.last.currency).to eq 'EUR'
        expect(store_credit_table).to have_content('€100.00')
      end
    end
  end

  describe 'updating store credit' do
    let(:updated_amount) { '99.0' }

    before do
      visit spree.admin_path
      click_link 'Users'
      click_link store_credit.user.email
      click_link 'Store Credits'
      allow_any_instance_of(Spree::Admin::StoreCreditsController).to receive(:try_spree_current_user).and_return(admin_user)
    end

    it 'creates store credit and associate it with the user' do
      click_link 'Edit'
      page.fill_in 'store_credit_amount', with: updated_amount
      click_button 'Update'

      expect(page).to have_current_path(spree.admin_user_store_credits_path(store_credit.user))
      store_credit_table = page.first('table')
      expect(store_credit_table).to have_content(Spree::Money.new(updated_amount, currency: store_credit.currency).to_s)
      expect(store_credit.reload.amount.to_f).to eq updated_amount.to_f
    end
  end

  describe 'deleting store credit', js: true do
    before do
      visit spree.admin_path
      click_link 'Users'
      click_link store_credit.user.email
      click_link 'Store Credits'
      allow_any_instance_of(Spree::Admin::StoreCreditsController).to receive(:try_spree_current_user).and_return(admin_user)
    end

    it 'updates store credit in lifetime stats' do
      accept_confirm do
        click_icon :delete
      end
      expect(page).to have_css('#user-lifetime-stats #store_credit', text: Spree::Money.new(0).to_s)
    end
  end

  describe 'non-existent user' do
    before do
      visit spree.admin_path
      click_link 'Users'
      click_link store_credit.user.email
      store_credit.user.destroy
      allow(Spree.user_class).to receive(:find_by).and_return(nil)
      click_link 'Store Credits'
      allow_any_instance_of(Spree::Admin::StoreCreditsController).to receive(:try_spree_current_user).and_return(admin_user)
    end

    it 'displays flash withe error' do
      expect(page).to have_content(Spree.t(:user_not_found))
    end
  end
end
