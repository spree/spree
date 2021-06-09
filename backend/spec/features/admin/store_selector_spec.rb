require 'spec_helper'

describe 'Admin store selector', type: :feature, js: true do
  stub_authorization!

  let!(:admin_user) { create(:admin_user) }

  let!(:store) { create(:store, url: "www.example1.com") }

  before do
    visit spree.admin_path
  end

  it "should allow to change the url to the seleted store" do
    expect(current_url).not_to include("#{store.formatted_url}")
    find("select#store_select").find(:xpath, 'option[2]').select_option
    expect(current_url).to eq "#{store.formatted_url}/admin"
  end
end