require 'spec_helper'
require 'active_job/continuation/test_helper'

describe Spree::PriceLists::SyncCurrenciesJob, type: :job do
  describe '#perform' do
    subject { described_class.perform_now(store.id) }

    let(:store) { create(:store, supported_currencies: 'USD') }
    let(:product) { create(:product, store: store) }
    let(:price_list) { create(:price_list, store: store) }
    let!(:empty_list) { create(:price_list, store: store) }

    before do
      price_list.add_products([product.id])
      price_list.bulk_update_prices(price_list.prices.map { |price| { id: price.id, amount: '9.50' } })
      # The store starts selling in EUR after the products were added.
      store.update_columns(supported_currencies: 'USD,EUR')
    end

    it 'adds the missing currency\'s placeholder rows and leaves the rest alone' do
      usd_before = price_list.prices.where(currency: 'USD').pluck(:id, :amount)

      expect { subject }.to change { price_list.prices.where(currency: 'EUR').count }.from(0).to(product.variants_including_master.count)

      expect(price_list.prices.where(currency: 'EUR').pluck(:amount).uniq).to eq([nil])
      expect(price_list.prices.where(currency: 'USD').pluck(:id, :amount)).to match_array(usd_before)
      expect(empty_list.prices).to be_empty
    end

    it 'does nothing twice' do
      subject

      expect { described_class.perform_now(store.id) }.not_to change { Spree::Price.count }
    end

    it 'skips a store that no longer exists' do
      expect { described_class.perform_now(0) }.not_to raise_error
    end

    describe 'interruption and resume' do
      include ActiveJob::Continuation::TestHelper

      around do |example|
        original = ActiveJob::Base.queue_adapter
        ActiveJob::Base.queue_adapter = :test
        example.run
      ensure
        ActiveJob::Base.queue_adapter = original
      end

      let(:other_product) { create(:product, store: store) }
      let!(:second_list) { create(:price_list, store: store) }

      before do
        # Built the way the first list was: while the store sold in USD only,
        # so the walk has a missing currency to add on both lists.
        store.update_columns(supported_currencies: 'USD')
        second_list.add_products([other_product.id])
        store.update_columns(supported_currencies: 'USD,EUR')
      end

      it 'picks up with the next list rather than starting the walk over' do
        described_class.perform_later(store.id)

        # The cursor is the list synced last, so the interruption lands after
        # the first list's rows exist and before the second's.
        interrupt_job_during_step(described_class, :sync_price_lists, cursor: price_list.id + 1) { perform_enqueued_jobs }
        expect(price_list.prices.where(currency: 'EUR')).to exist
        expect(second_list.prices.where(currency: 'EUR')).not_to exist

        perform_enqueued_jobs

        expect(second_list.prices.where(currency: 'EUR').count).to eq(other_product.variants_including_master.count)
      end
    end
  end
end
