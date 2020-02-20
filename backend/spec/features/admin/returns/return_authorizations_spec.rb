require 'spec_helper'

describe 'Return Authorizations', type: :feature do
  stub_authorization!

  describe 'listing' do
    let!(:return_authorization) { create(:return_authorization, created_at: Time.current) }
    let!(:return_authorization_2) { create(:return_authorization, created_at: Time.current - 1.day) }

    before do
      visit spree.admin_return_authorizations_path
    end

    it 'lists return authorizations sorted by created_at' do
      within_row(1) { expect(page).to have_content(return_authorization.number) }
      within_row(2) { expect(page).to have_content(return_authorization_2.number) }
    end

    it 'displays order number' do
      within_row(1) { expect(page).to have_content(return_authorization.order.number) }
    end

    it 'displays return authorization number' do
      within_row(1) { expect(page).to have_content(return_authorization.number) }
    end

    it 'displays state' do
      return_authorization_state = Spree.t("return_authorization_states.#{return_authorization.state}")
      within_row(1) { expect(page).to have_content(return_authorization_state) }
    end

    it 'has edit link' do
      expect(page).to have_css('.icon-edit')
    end
  end

  describe 'searching' do
    let!(:return_authorization) { create(:return_authorization, state: 'authorized') }
    let!(:return_authorization_2) { create(:return_authorization, state: 'canceled') }

    before do
      visit spree.admin_return_authorizations_path
    end

    it 'searches on number' do
      click_on 'Filter'
      fill_in 'q_number_cont', with: return_authorization.number
      click_on 'Search'

      expect(page).to have_content(return_authorization.number)
      expect(page).not_to have_content(return_authorization_2.number)

      click_on 'Filter'
      fill_in 'q_number_cont', with: return_authorization_2.number
      click_on 'Search'

      expect(page).to have_content(return_authorization_2.number)
      expect(page).not_to have_content(return_authorization.number)
    end

    it 'searches on status' do
      click_on 'Filter'
      select Spree.t("return_authorization_states.#{return_authorization.state}"), from: 'Status'
      click_on 'Search'

      expect(page).to have_content(return_authorization.number)
      expect(page).not_to have_content(return_authorization_2.number)

      click_on 'Filter'
      select Spree.t("return_authorization_states.#{return_authorization_2.state}"), from: 'Status'
      click_on 'Search'

      expect(page).to have_content(return_authorization_2.number)
      expect(page).not_to have_content(return_authorization.number)
    end

    it 'renders selected filters', js: true do
      click_on 'Filter'

      within('#table-filter') do
        fill_in 'q_number_cont', with: 'RX001-01'
        select2 'Authorized', from: 'Status'
      end

      click_on 'Search'

      within('.table-active-filters') do
        expect(page).to have_content('Number: RX001-01')
        expect(page).to have_content('Status: Authorized')
      end
    end
  end

  describe 'link' do
    let!(:return_authorization) { create(:return_authorization) }

    describe 'order number' do
      it 'opens orders edit page' do
        visit spree.admin_return_authorizations_path
        click_link return_authorization.order.number
        expect(page).to have_content("Orders / #{return_authorization.order.number}")
      end
    end

    describe 'return authorization number' do
      it 'opens return authorization edit page' do
        visit spree.admin_return_authorizations_path
        click_link return_authorization.number
        expect(page).to have_content(return_authorization.number)
      end
    end

    describe 'authorized' do
      let!(:return_authorization) { create(:return_authorization, state: 'authorized') }
      let!(:return_authorization_2) { create(:return_authorization, state: 'canceled') }

      it 'only shows authorized return authorizations' do
        visit spree.admin_return_authorizations_path
        within('.nav-tabs') do
          click_link 'Authorized'
        end

        expect(page).to have_content(return_authorization.number)
        expect(page).not_to have_content(return_authorization_2.number)
      end

      it 'preselects authorized status in filter' do
        visit spree.admin_return_authorizations_path
        within('.nav-tabs') do
          click_link 'Authorized'
        end

        within('#table-filter') do
          return_authorization_state = Spree.t("return_authorization_states.#{return_authorization.state}")
          expect(page).to have_select('Status', selected: return_authorization_state)
        end
      end
    end

    describe 'canceled' do
      let!(:return_authorization) { create(:return_authorization, state: 'canceled') }
      let!(:return_authorization_2) { create(:return_authorization, state: 'authorized') }

      it 'only shows canceled return authorizations' do
        visit spree.admin_return_authorizations_path
        within('.nav-tabs') do
          click_link 'Canceled'
        end

        expect(page).to have_content(return_authorization.number)
        expect(page).not_to have_content(return_authorization_2.number)
      end

      it 'preselects canceled status in filter' do
        visit spree.admin_return_authorizations_path
        within('.nav-tabs') do
          click_link 'Canceled'
        end

        within('#table-filter') do
          return_authorization_state = Spree.t("return_authorization_states.#{return_authorization.state}")
          expect(page).to have_select('Status', selected: return_authorization_state)
        end
      end
    end
  end
end
