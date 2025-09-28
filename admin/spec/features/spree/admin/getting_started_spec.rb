require 'spec_helper'

RSpec.feature 'Getting Started' do
  stub_authorization!
  let(:store) { Spree::Store.default }
  let(:us_country) { Spree::Country.find_by(iso: 'US') }
  let!(:ny_state) { create(:state, name: 'New York', abbr: 'NY', country: us_country) }

  describe 'Getting started tasks', js: true do
    describe 'setup taxes collection' do
      context 'when there are no tax rates' do
        it 'asks to setup taxes' do
          visit spree.admin_getting_started_path
          click_on Spree.t('admin.store_setup_tasks.setup_taxes_collection')

          expect(page).to have_text Spree.t('admin.store_setup_tasks.taxes.copy', link: spree.admin_tax_rates_path)
        end
      end

      context 'tax rates are added' do
        before do
          create(:tax_rate)
          visit spree.admin_getting_started_path
        end

        it 'confirms the setup' do
          expect(page.find('span', text: Spree.t('admin.store_setup_tasks.setup_taxes_collection')).ancestor('a')).to have_css('i.bg-success')
        end
      end
    end

    describe 'set customer support email' do
      before do
        visit spree.admin_getting_started_path
      end

      scenario 'Retailer adds and updates the customer support email' do
        click_on 'Set customer support email'
        within '#set_customer_support_email' do
          click_on 'Edit'

          fill_in 'Customer Support Email', with: 'support@example.com'
          click_on 'Save'
        end

        expect(page).to have_content("Store \"#{store.name}\" has been successfully updated!")
      end
    end
  end
end
