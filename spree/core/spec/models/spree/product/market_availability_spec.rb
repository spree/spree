require 'spec_helper'

RSpec.describe Spree::Product::MarketAvailability do
  let(:store) { @default_store }
  let(:europe) { create(:market, store: store, name: 'Europe') }
  let(:australia) { create(:market, store: store, name: 'Australia') }
  let(:product) { create(:product, store: store) }

  def restrict(mode, *markets)
    product.update!(market_availability: mode, market_ids: markets.map(&:prefixed_id))
    product.reload
  end

  describe '#available_in_market?' do
    it 'is available everywhere when unrestricted' do
      expect(product.market_availability).to be_nil
      expect(product.available_in_market?(europe)).to be true
    end

    it 'leaves out the named markets under all_except' do
      restrict('all_except', europe)

      expect(product.available_in_market?(europe)).to be false
      expect(product.available_in_market?(australia)).to be true
    end

    it 'keeps to the named markets under only' do
      restrict('only', australia)

      expect(product.available_in_market?(australia)).to be true
      expect(product.available_in_market?(europe)).to be false
    end

    # New markets need nothing written: each mode already answers for them.
    it 'answers for a market added after the restriction' do
      restrict('all_except', europe)
      later = create(:market, store: store)
      expect(product.available_in_market?(later)).to be true

      restrict('only', europe)
      expect(product.available_in_market?(later)).to be false
    end

    it 'restricts nothing without a market' do
      restrict('only', australia)

      expect(product.available_in_market?(nil)).to be true
    end
  end

  describe '.available_in_market' do
    let!(:everywhere) { create(:product, store: store) }

    it 'splits the products the same way the predicate does' do
      restrict('all_except', europe)
      kept_to_europe = create(:product, store: store, market_availability: 'only', market_ids: [europe.prefixed_id])

      expect(Spree::Product.available_in_market(europe)).to include(everywhere, kept_to_europe)
      expect(Spree::Product.available_in_market(europe)).not_to include(product)
      expect(Spree::Product.available_in_market(australia)).to include(everywhere, product)
      expect(Spree::Product.available_in_market(australia)).not_to include(kept_to_europe)
    end

    it 'restricts nothing without a market' do
      restrict('only', europe)

      expect(Spree::Product.available_in_market(nil)).to include(product, everywhere)
    end
  end

  describe 'writing' do
    it 'stores all as no restriction and forgets the markets' do
      restrict('all_except', europe)
      product.update!(market_availability: 'all')

      expect(product.reload.market_availability).to be_nil
      expect(product.market_availability_entries).to be_empty
    end

    it 'needs a market for a restricted mode' do
      product.assign_attributes(market_availability: 'only', market_ids: [])

      expect(product).not_to be_valid
      expect(product.errors[:market_ids]).to be_present
    end

    it 'refuses a switch between restricted modes that does not name the markets again' do
      restrict('only', europe)

      expect(product.update(market_availability: 'all_except')).to be false
      expect(product.reload.market_availability).to eq('only')
      expect(product.update(market_availability: 'all_except', market_ids: [europe.prefixed_id])).to be true
    end

    it 'refuses an unknown mode' do
      product.market_availability = 'some'

      expect(product).not_to be_valid
    end

    it "drops another store's markets" do
      foreign = create(:market, store: create(:store))
      product.update(market_availability: 'only', market_ids: [foreign.prefixed_id, europe.prefixed_id])

      expect(product.reload.market_ids).to contain_exactly(europe.id)
    end

    it 'changes no markets when the save is refused' do
      restrict('only', australia)

      expect(product.update(name: '', market_ids: [europe.prefixed_id])).to be false
      expect(product.reload.market_ids).to contain_exactly(australia.id)
    end

    it 'keeps no markets for an unrestricted product' do
      product.update!(market_ids: [europe.prefixed_id])

      expect(product.market_availability_entries.reload).to be_empty
    end

    # The restriction is the product's, so it outlives the market it names.
    it "survives the named market's soft delete and restore" do
      restrict('only', australia)
      australia.destroy

      expect(product.reload).to be_valid
      expect(product.available_in_market?(europe)).to be false

      australia.restore
      expect(product.reload.available_in_market?(australia)).to be true
    end

    # The dashboard sends back the ids it read, deleted market included.
    it 'keeps a deleted market it already names when the same ids come back' do
      restrict('all_except', australia)
      australia.destroy

      product.reload.update!(name: 'Renamed', market_ids: [australia.prefixed_id])
      australia.restore

      expect(product.reload.available_in_market?(australia)).to be false
    end

    it 'keeps the restriction through a soft delete and restore' do
      restrict('all_except', europe)
      product.destroy
      product.restore(recursive: true)

      expect(product.reload.available_in_market?(europe)).to be false
    end
  end
end
