require 'spec_helper'

describe 'new reimbursement type', type: :feature do
  stub_authorization!

  before do
    visit '/admin/reimbursement_types/new'
  end

  it 'view should have select field' do
    expect(page).to have_css('div#reimbursement_type_type_field.form-group.field')
  end

  context 'with valid attributes' do
    it 'credit type' do
      fill_in 'Name', with: 'Credit'
      select 'Spree::ReimbursementType::Credit', from: 'reimbursement_type_type'

      expect { click_button 'Create' }.to change(Spree::ReimbursementType, :count).by(1)

      expect(page).to have_content('Credit')
    end

    it 'exchange type' do
      fill_in 'Name', with: 'Exchange'
      select 'Spree::ReimbursementType::Exchange', from: 'reimbursement_type_type'

      expect { click_button 'Create' }.to change(Spree::ReimbursementType, :count).by(1)

      expect(page).to have_content('Exchange')
    end

    it 'original payment type' do
      fill_in 'Name', with: 'OriginalPayment'
      select 'Spree::ReimbursementType::OriginalPayment', from: 'reimbursement_type_type'

      expect { click_button 'Create' }.to change(Spree::ReimbursementType, :count).by(1)

      expect(page).to have_content('OriginalPayment')
    end

    it 'store credit type' do
      fill_in 'Name', with: 'StoreCredit'
      select 'Spree::ReimbursementType::StoreCredit', from: 'reimbursement_type_type'

      expect { click_button 'Create' }.to change(Spree::ReimbursementType, :count).by(1)

      expect(page).to have_content('StoreCredit')
    end
  end

  context 'with invalid params' do
    it 'without name' do
      fill_in 'Name', with: ''
      select 'Spree::ReimbursementType::StoreCredit', from: 'reimbursement_type_type'

      expect { click_button 'Create' }.not_to change(Spree::ReimbursementType, :count)

      expect(page).to have_content("Name can't be blank")
    end
  end
end
