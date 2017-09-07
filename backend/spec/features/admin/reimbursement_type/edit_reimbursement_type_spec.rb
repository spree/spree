require 'spec_helper'

describe 'edit reimbursement type', type: :feature do
  stub_authorization!
  let(:r_type) do
    create(:reimbursement_type,
           name: 'Exchange',
           type: 'Spree::ReimbursementType::Exchange',
           active: true,
           mutable: true)
  end

  before do
    visit "/admin/reimbursement_types/#{r_type.id}/edit"
  end

  context 'with valid attributes' do
    it 'change name, active and mutable' do
      fill_in 'Name', with: 'New Credit'
      uncheck 'Mutable'
      uncheck 'Active'

      expect { click_button 'Create' }.not_to change(Spree::ReimbursementType, :count)

      r_type.reload

      expect(r_type.active).to eq false
      expect(r_type.mutable).to eq false
      expect(page).to have_content('New Credit')
    end
  end

  it 'view should have select field' do
    expect(page).not_to have_css('div#reimbursement_type_type_field.form-group.field')
  end
end
