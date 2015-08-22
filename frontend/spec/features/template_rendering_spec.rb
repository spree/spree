require 'spec_helper'

describe "Template rendering", :type => :feature do
  before { create(:store, default: true) }

  after do
    Capybara.ignore_hidden_elements = true
  end

  before do
    Capybara.ignore_hidden_elements = false
  end

  it 'layout should have canonical tag referencing site url' do
    visit spree.root_path
    expect(find('link[rel=canonical]')[:href]).to eql('http://www.example.com/')
  end
end
