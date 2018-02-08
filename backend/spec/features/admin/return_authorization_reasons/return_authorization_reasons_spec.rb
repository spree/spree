require 'spec_helper'

describe 'ReturnAuthorizationReason', type: :feature, js: true do
  stub_authorization!

  let!(:order) { create(:shipped_order) }
  let!(:stock_location) { create(:stock_location) }
  let!(:rma_reason) { create(:return_authorization_reason, name: 'Defect #1', mutable: true) }
  let!(:rma_reason2) { create(:return_authorization_reason, name: 'Defect #2', mutable: true) }

  before do
    create(
      :return_authorization,
      order: order,
      stock_location: stock_location,
      reason: rma_reason
    )

    visit spree.admin_return_authorization_reasons_path
  end

  describe 'destroy' do
    it 'has return authorization reasons' do
      within('.table #return_authorization_reasons') do
        expect(page).to have_content(rma_reason.name)
        expect(page).to have_content(rma_reason2.name)
      end
    end

    context 'should not destroy an associated option type' do
      before { within_row(1) { delete_product_property } }

      it 'has persisted return authorization reasons' do
        within('.table #return_authorization_reasons') do
          expect(page).to have_content(rma_reason.name)
          expect(page).to have_content(rma_reason2.name)
        end
      end

      it(js: false) { expect(Spree::ReturnAuthorizationReason.all).to include(rma_reason) }
      it(js: false) { expect(Spree::ReturnAuthorizationReason.all).to include(rma_reason2) }
    end

    context 'should allow an admin to destroy a non associated option type' do
      before { within_row(2) { delete_product_property } }

      it 'has persisted return authorization reasons' do
        within('.table #return_authorization_reasons') do
          expect(page).to have_content(rma_reason.name)
          expect(page).not_to have_content(rma_reason2.name)
        end
      end

      it(js: false) { expect(Spree::ReturnAuthorizationReason.all).to include(rma_reason) }
      it(js: false) { expect(Spree::ReturnAuthorizationReason.all).not_to include(rma_reason2) }
    end

    def delete_product_property
      spree_accept_alert do
        click_icon :delete
        wait_for_ajax
      end
      wait_for_ajax
    end
  end
end
