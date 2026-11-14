require 'spec_helper'

RSpec.describe 'sample_data/collections.rb' do
  let!(:store) { @default_store }

  # Discounted and recent — matches both automatic collections.
  let!(:recent) { create(:product, store: store, price: 20, compare_at_price: 30) }
  # Full price and long past the AvailableOn window — matches neither. The
  # window reads `created_at`/`available_on` directly, so set the columns.
  let!(:old_product) do
    create(:product, store: store, price: 15).tap do |product|
      product.update_columns(available_on: 400.days.ago, created_at: 400.days.ago)
    end
  end

  def load_sample_file
    load Spree::Core::Engine.root.join('db', 'sample_data', 'collections.rb').to_s
  end

  it 'creates the three collections with working membership' do
    load_sample_file

    new_arrivals = store.collections.find_by(permalink: 'new-arrivals')
    on_sale = store.collections.find_by(permalink: 'on-sale')
    best_sellers = store.collections.find_by(permalink: 'best-sellers')

    aggregate_failures do
      expect(new_arrivals).to be_automatic
      expect(new_arrivals.sort_order).to eq('available_on desc')
      expect(new_arrivals.rules.map(&:type)).to eq(['Spree::CollectionRules::AvailableOn'])
      expect(new_arrivals.products).to include(recent)
      expect(new_arrivals.products).not_to include(old_product)

      expect(on_sale).to be_automatic
      expect(on_sale.sort_order).to eq('price asc')
      expect(on_sale.rules.map(&:type)).to eq(['Spree::CollectionRules::Sale'])
      expect(on_sale.products).to include(recent)
      expect(on_sale.products).not_to include(old_product)

      expect(best_sellers).to be_manual
      expect(best_sellers.sort_order).to eq('best_selling')
      expect(best_sellers.products).to be_present
    end
  end

  it 'is idempotent' do
    load_sample_file

    expect { load_sample_file }.not_to change {
      [store.collections.count, Spree::CollectionRule.count, Spree::ProductCollection.count]
    }
  end
end
