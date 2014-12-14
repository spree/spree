require 'spec_helper'

describe "Template rendering", type: :feature do

  after do
    Capybara.ignore_hidden_elements = true
  end

  before do
    Capybara.ignore_hidden_elements = false
  end

  it 'layout should have canonical tag referencing site url' do
    Spree::Store.create!(code: 'spree', name: 'My Spree Store', url: 'spreestore.example.com', mail_from_address: 'test@example.com')

    visit spree.root_path
    expect(find('link[rel=canonical]')[:href]).to eql('http://spreestore.example.com/')
  end
end
