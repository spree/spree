require 'spec_helper'

module Spree
  describe "Countries" do
    stub_authorization!

    let!(:country) { create(:country) }

    it "deletes a state", js: true do
      visit spree.admin_countries_path
      click_icon :trash
      page.driver.browser.switch_to.alert.accept
      wait_for_ajax

      expect { Country.find(country.id) }.to raise_error
    end
  end
end
