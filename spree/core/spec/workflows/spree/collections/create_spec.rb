require 'spec_helper'

RSpec.describe Spree::Collections::Create do
  let(:store) { @default_store }
  let!(:pos) { create(:channel, store: store, name: 'POS', code: 'pos') }
  let!(:retired) { create(:channel, store: store, name: 'Retired', code: 'retired', active: false) }

  subject(:result) { described_class.call(store: store, attributes: attributes) }

  context 'without publications' do
    let(:attributes) { { name: 'Summer' } }

    it 'publishes on every active channel of the store' do
      expect(result).to be_success
      expect(result.value.reload.channels).to contain_exactly(store.default_channel, pos)
    end

    it 'publishes collection.published once per channel' do
      events = []
      allow_any_instance_of(Spree::Collection).to receive(:publish_event) { |_collection, name, _payload, metadata| events << [name, metadata[:channel_id]] }

      result

      expect(events).to contain_exactly(['collection.published', store.default_channel.prefixed_id], ['collection.published', pos.prefixed_id])
    end
  end

  context 'with publications' do
    let(:attributes) { { name: 'Staged', publications: [{ channel_id: pos.prefixed_id, published_at: 1.week.from_now }] } }

    it 'publishes only where the payload says' do
      expect(result.value.reload.channels).to contain_exactly(pos)
      expect(result.value.reload.publications.first.published_at).to be > Time.current
    end
  end

  context 'with an empty publications set' do
    let(:attributes) { { name: 'Draft', publications: [] } }

    it 'creates the collection unpublished' do
      expect(result.value.reload.publications).to be_empty
    end
  end

  context 'when the collection is invalid' do
    let(:attributes) { { name: '' } }

    it 'fails without publishing' do
      expect(result).to be_failure
      expect(Spree::CollectionPublication.count).to eq(0)
    end
  end
end
