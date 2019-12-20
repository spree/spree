require 'spec_helper'

describe 'Template rendering', type: :feature do
  it 'layout should have canonical tag referencing site url' do
    Spree::Store.default.update(url: 'spreestore.example.com')

    visit spree.root_path
    expect(find('link[rel=canonical]', visible: false)[:href]).to eql('http://spreestore.example.com/')
  end
end
