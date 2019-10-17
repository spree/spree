require 'spec_helper'

describe 'Template rendering', type: :feature do
  it 'layout should have canonical tag referencing site url' do
    Spree::Store.create!(
      code: 'spree',
      name: 'My Spree Store',
      url: 'spreestore.example.com',
      mail_from_address: 'test@example.com',
      default_currency: 'USD'
    )

    visit spree.root_path
    expect(find('link[rel=canonical]', visible: false)[:href]).to eql('http://spreestore.example.com/')
  end
end
