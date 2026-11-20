require 'spec_helper'

RSpec.describe Spree::Api::V3::StoreSerializer do
  let(:store) { create(:store) }

  describe 'as the store.updated payload' do
    let(:logo) do
      ActiveStorage::Blob.create_and_upload!(
        io: File.open(Spree::Core::Engine.root.join('spec', 'fixtures', 'thinking-cat.jpg')),
        filename: 'logo.jpg',
        content_type: 'image/jpeg'
      )
    end

    it 'is what the store publishes' do
      expect(Spree::Events.catalog.find('store.updated').payload_serializer).to eq(described_class)
    end

    it 'carries only the public storefront fields' do
      payload = store.event_payload_for('store.updated')

      expect(payload.keys).to match_array(
        %w[id name seo_title meta_description meta_keywords logo_url facebook twitter instagram customer_support_email]
      )
    end

    it 'carries the logo URL' do
      store.logo.attach(logo)

      expect(store.event_payload_for('store.updated')['logo_url']).to be_present
    end

    it 'describes the store in its default language whatever language the change was made in' do
      Mobility.with_locale(:de) { store.name = 'Laden' }

      payload = Mobility.with_locale(:de) { store.event_payload_for('store.updated') }

      expect(payload['name']).to eq(store.name)
      expect(payload['name']).not_to eq('Laden')
    end

    it 'reads a default language other than the application default from the store itself' do
      store.default_market.update!(supported_locales: 'en,de')
      store.reload.upsert_translations('de' => { 'name' => 'Alter Laden' })
      store.reload
      allow(store).to receive(:default_locale).and_return('de')
      Spree::Current.with_content_locale('de') { Mobility.with_locale(:de) { store.update!(name: 'Laden') } }

      expect(store.reload.event_payload_for('store.updated')['name']).to eq('Laden')
    end
  end
end
