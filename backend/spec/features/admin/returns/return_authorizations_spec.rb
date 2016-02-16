# encoding: utf-8
require 'spec_helper'

describe "Return Authorizations", type: :feature do
  stub_authorization!

  describe "listing" do
    let!(:return_authorization) { create(:return_authorization, created_at: Time.current) }
    let!(:return_authorization_2) { create(:return_authorization, created_at: Time.current - 1.day) }

    before(:each) do
      visit spree.admin_return_authorizations_path
    end

    it "should list sorted by created_at" do
      within_row(1) { expect(page).to have_content(return_authorization.number) }
      within_row(2) { expect(page).to have_content(return_authorization_2.number) }
    end

    it "should display order number" do
      within_row(1) { expect(page).to have_content(return_authorization.order.number) }
    end

    it "should display return authorization number" do
      within_row(1) { expect(page).to have_content(return_authorization.number) }
    end

    it 'should display state' do
      within_row(1) { expect(page).to have_content(Spree.t("return_authorization_states.#{return_authorization.state}")) }
    end

    it 'should have edit link' do
      expect(page).to have_css('.icon-edit')
    end
  end

  describe "searching" do
    let!(:return_authorization) { create(:return_authorization, state: 'authorized') }
    let!(:return_authorization_2) { create(:return_authorization, state: 'canceled') }

    it "should search on number" do
      visit spree.admin_return_authorizations_path

      click_on 'Filter'
      fill_in "q_number_cont", with: return_authorization.number
      click_on 'Search'

      expect(page).to have_content(return_authorization.number)
      expect(page).not_to have_content(return_authorization_2.number)

      click_on 'Filter'
      fill_in "q_number_cont", with: return_authorization_2.number
      click_on 'Search'

      expect(page).to have_content(return_authorization_2.number)
      expect(page).not_to have_content(return_authorization.number)
    end

    it "should search on status" do
      visit spree.admin_return_authorizations_path

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
  end

  describe 'link' do
    let!(:return_authorization) { create(:return_authorization) }

    describe 'order number' do
      it 'should open orders edit page' do
        visit spree.admin_return_authorizations_path
        click_link return_authorization.order.number
        expect(page).to have_content("Orders / #{return_authorization.order.number}")
      end
    end

    describe 'return authorization number' do
      it 'should open return authorization edit page' do
        visit spree.admin_return_authorizations_path
        click_link return_authorization.number
        expect(page).to have_content("Return Authorization #{return_authorization.number}")
      end
    end

    describe 'authorized' do
      let!(:return_authorization) { create(:return_authorization, state: 'authorized') }
      let!(:return_authorization_2) { create(:return_authorization, state: 'canceled') }

      it 'should only show authorized return authorizations' do
        visit spree.admin_return_authorizations_path
        within('.nav-tabs') do
          click_link 'Authorized'
        end

        expect(page).to have_content(return_authorization.number)
        expect(page).not_to have_content(return_authorization_2.number)
      end

      it 'should preselect authorized status in filter' do
        visit spree.admin_return_authorizations_path
        within('.nav-tabs') do
          click_link 'Authorized'
        end

        within('#table-filter') do
          expect(page).to have_select("Status", selected: Spree.t("return_authorization_states.#{return_authorization.state}"))
        end
      end
    end

    describe 'canceled' do
      let!(:return_authorization) { create(:return_authorization, state: 'canceled') }
      let!(:return_authorization_2) { create(:return_authorization, state: 'authorized') }

      it 'should only show canceled return authorizations' do
        visit spree.admin_return_authorizations_path
        within('.nav-tabs') do
          click_link 'Canceled'
        end

        expect(page).to have_content(return_authorization.number)
        expect(page).not_to have_content(return_authorization_2.number)
      end

      it 'should preselect canceled status in filter' do
        visit spree.admin_return_authorizations_path
        within('.nav-tabs') do
          click_link 'Canceled'
        end

        within('#table-filter') do
          expect(page).to have_select("Status", selected: Spree.t("return_authorization_states.#{return_authorization.state}"))
        end
      end
    end
  end
end
