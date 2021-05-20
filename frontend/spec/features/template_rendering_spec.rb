require 'spec_helper'

describe 'Template rendering', type: :feature do
  it 'layout should have canonical tag referencing site url' do
    Spree::Store.default.update(
      name: 'My Spree Store',
      url: 'spreestore.example.com',
      mail_from_address: 'test@example.com',
      default_currency: 'USD',
      supported_currencies: 'USD'
    )

    visit spree.root_path
    expect(find('link[rel=canonical]', visible: false)[:href]).to eql('http://spreestore.example.com/')
  end

  describe 'favicon link' do
    let(:store) { Spree::Store.default }
    let(:favicon_link) { find('link[rel="shortcut icon"]', visible: false) }

    context 'when a store has its own favicon' do
      let(:favicon_attachment) { Rack::Test::UploadedFile.new(file_fixture('store_favicon.ico')) }

      before do
        store.favicon_image.attach(favicon_attachment)
      end

      it 'builds a store favicon link' do
        visit spree.root_path

        expect(favicon_link[:type]).to eq('image/x-icon')
        expect(favicon_link[:href]).to end_with('store_favicon.ico')

        expect(URI.parse(favicon_link[:href]).host).to be_present
      end
    end

    context 'when a store has no favicon' do
      it 'builds a default favicon link' do
        visit spree.root_path

        expect(favicon_link[:type]).to eq('image/x-icon')
        expect(favicon_link[:href]).to match(/assets\/favicon-.+\.ico/)
      end
    end
  end
end
