require 'spec_helper'

describe 'Homepage', type: :feature do
  context 'as admin user' do
    stub_authorization!

    context 'visiting the homepage' do
      before do
        visit spree.admin_path
      end

      it "has header text 'Orders'" do
        within('h1') { expect(page).to have_content('Orders') }
      end

      it 'has a link to overview' do
        within('header') { page.find(:xpath, "//a[@href='/admin']") }
      end

      it 'has a link to orders' do
        page.find_link('Orders')['/admin/orders']
      end

      it 'has a link to products' do
        page.find_link('Products')['/admin/products']
      end

      it 'has a link to reports' do
        page.find_link('Reports')['/admin/reports']
      end

      it 'has a link to configuration' do
        page.find_link('Configuration')['/admin/configurations']
      end

      it 'has a link to return authorizations' do
        within('.sidebar') { page.find_link('Return Authorizations')['/admin/return_authorizations'] }
      end

      it 'has a link to customer returns' do
        within('.sidebar') { page.find_link('Customer Returns')['/admin/customer_returns'] }
      end

      context 'version number' do
        it 'is displayed' do
          within('.sidebar') { expect(page).to have_content(Spree.version) }
        end

        context 'if turned off' do
          before { Spree::Config[:admin_show_version] = false }

          it 'is not displayed' do
            visit spree.admin_path
            within('.sidebar') { expect(page).not_to have_content(Spree.version) }
          end
        end
      end
    end

    context 'visiting the products tab' do
      before do
        visit spree.admin_products_path
      end

      it 'has a link to products' do
        within('.sidebar') { page.find_link('Products')['/admin/products'] }
      end

      it 'has a link to option types' do
        within('.sidebar') { page.find_link('Option Types')['/admin/option_types'] }
      end

      it 'has a link to properties' do
        within('.sidebar') { page.find_link('Properties')['/admin/properties'] }
      end

      it 'has a link to prototypes' do
        within('.sidebar') { page.find_link('Prototypes')['/admin/prototypes'] }
      end
    end
  end

  context 'as fakedispatch user' do
    before do
      allow_any_instance_of(Spree::Admin::BaseController).to receive(:spree_current_user).and_return(nil)
    end

    custom_authorization! do |_user|
      can [:admin, :edit, :index, :read], Spree::Order
    end

    it 'only displays tabs fakedispatch has access to' do
      visit spree.admin_path
      expect(page).to have_link('Orders')
      expect(page).not_to have_link('Products')
      expect(page).not_to have_link('Promotions')
      expect(page).not_to have_link('Reports')
      expect(page).not_to have_link('Configurations')
    end
  end
end
