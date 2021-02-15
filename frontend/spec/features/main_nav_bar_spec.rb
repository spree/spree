require 'spec_helper'

describe 'Main navigation bar', type: :feature do
  describe 'change store' do
    shared_examples 'change store not available' do
      it 'does not render stores list' do
        expect(page).not_to have_selector('div.stores-list')
      end
    end

    context 'when show_store_selector preference is set to true' do
      let!(:stores) { create_list(:store, stores_number, default_country: create(:country)) }

      before do
        reset_spree_preferences do |config|
          config.show_store_selector = true
        end

        visit spree.root_path
      end

      context 'when there is one supported currency' do
        let(:stores_number) { 0 }

        it_behaves_like 'change store not available'
      end

      context 'when there are more than one supported currencies' do
        let(:stores_number) { 2 }
        let(:first_store) { stores.first }
        let(:first_store_currency_symbol) { ::Money::Currency.find(first_store.default_currency).symbol }
        let(:first_link_name) { "#{Spree.t('i18n.this_file_language', locale: first_store.default_locale)} (#{first_store_currency_symbol})" }
        let(:first_url) { first_store.formatted_url }
        let(:second_store) { stores.second }
        let(:second_store_currency_symbol) { ::Money::Currency.find(second_store.default_currency).symbol }
        let(:second_link_name) { "#{Spree.t('i18n.this_file_language', locale: second_store.default_locale)} (#{first_store_currency_symbol})" }
        let(:second_url) { second_store.formatted_url }

        it 'shows currency selector button' do
          within('.internationalization-options') { expect(page).to have_button(id: 'internationalization-button-desktop') }
        end

        it 'currency selector button shows a links list to currencies' do
          within('.internationalization-options') { expect(page).to have_link(first_link_name, href: first_url) }
          within('.internationalization-options') { expect(page).to have_link(second_link_name, href: second_url) }
        end
      end
    end

    context 'when show_store_selector preference is set to false' do
      let!(:stores) { create_list(:store, stores_number) }

      before do
        reset_spree_preferences do |config|
          config.show_store_selector = false
        end

        visit spree.root_path
      end

      context 'when there is one supported currency' do
        let(:stores_number) { 0 }

        it_behaves_like 'change store not available'
      end

      context 'when there are more than one supported currencies' do
        let(:stores_number) { 2 }

        it_behaves_like 'change store not available'
      end
    end
  end
end
