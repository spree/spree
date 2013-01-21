require 'spec_helper'

describe "Promotions" do
  stub_authorization!

  context 'editing a promotion' do
    it 'should show correct field values' do
      create(:promotion, :name => 'Promo', :starts_at => '2013-08-14 01:02:03',
              :expires_at => '2013-08-15 01:02:03')

      visit spree.admin_path
      click_link 'Promotions'
      within_row(1) { click_icon :edit }

      find('input#promotion_name').value.should == 'Promo'
      find('input#promotion_starts_at').value.should == '2013/08/14'
      find('input#promotion_expires_at').value.should == '2013/08/15'
    end

  end
end
