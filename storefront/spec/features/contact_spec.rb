require 'spec_helper'

xdescribe 'Contact us', type: :feature do
  let!(:store) { Spree::Store.default }

  context 'contact us page' do
    it 'should sent mail' do
      visit spree.new_contact_path

      fill_in 'contact_name',  with: 'John 99'
      fill_in 'contact_email',  with: 'john@example.com'
      fill_in 'contact_message',  with: 'test message'
      click_button 'Send Message'

      expect(page).to have_content('Message sent!')
    end
  end
end
