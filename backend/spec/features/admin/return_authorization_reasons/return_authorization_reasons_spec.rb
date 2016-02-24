require 'spec_helper'

describe 'ReturnAuthorizationReason', type: :feature, js: true do
  stub_authorization!

  let!(:order) { create(:shipped_order) }
  let!(:stock_location) { create(:stock_location) }
  let!(:rma_reason) { create(:return_authorization_reason, mutable: true) }
  let!(:rma_reason2) { create(:return_authorization_reason, mutable: true) }

  let!(:return_authorization) do
    create(
      :return_authorization,
      order: order,
      stock_location: stock_location,
      reason: rma_reason
    )
  end

  before { visit spree.admin_return_authorization_reasons_path }

  describe 'destroy' do
    it { expect(page).to have_content(rma_reason.name) }
    it { expect(page).to have_content(rma_reason2.name) }

    context 'should not destroy an associated option type' do
      before { within_row(1) { delete_product_property } }
      it { check_property_row_count(2) }
      it { expect(page).to have_content(rma_reason.name) }
      it { expect(page).to have_content(rma_reason2.name) }
    end

    context 'should allow an admin to destroy a non associated option type' do
      before { within_row(2) { delete_product_property } }
      it { expect(page).to have_content(rma_reason.name) }
      it { expect(page).not_to have_content(rma_reason2.name) }
      it { check_property_row_count(1) }
    end

    def delete_product_property
      page.evaluate_script('window.confirm = function() { return true; }')
      click_icon :delete
      wait_for_ajax
    end

    def check_property_row_count(expected_row_count)
      click_link 'Configuration'
      click_link 'Return Authorization Reasons'
      expect(all('tbody#return_authorization_reasons tr').count).to eq(expected_row_count)
    end
  end
end
