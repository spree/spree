require 'spec_helper'

RSpec.feature 'Getting Started' do
  stub_authorization!
  let(:store) { Spree::Store.default }
  let(:us_country) { Spree::Country.find_by(iso: 'US') }
  let!(:ny_state) { create(:state, name: 'New York', abbr: 'NY', country: us_country) }

  describe 'Getting started tasks' do
    describe 'setup taxes collection' do
      context 'when there are no tax rates' do
        it 'asks to setup taxes' do
          visit spree.admin_getting_started_path
          find('#setup_task_setup_taxes_collection summary').click

          expect(page).to have_text Spree.t('admin.store_setup_tasks.taxes.copy', link: spree.admin_tax_rates_path)
        end
      end

      context 'tax rates are added' do
        before do
          create(:tax_rate)
          visit spree.admin_getting_started_path
        end

        it 'confirms the setup' do
          find('#setup_task_setup_taxes_collection summary').click

          expect(page).to have_text("You're all set! You can always manage your taxes")
        end
      end
    end

    describe 'set customer support email' do
      before do
        visit spree.admin_getting_started_path
      end

      scenario 'adds and updates the customer support email' do
        find('#setup_task_set_customer_support_email summary').click
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
