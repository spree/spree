require 'spec_helper'

# A seller's offer that nobody has approved must not be visible or buyable,
# anywhere a shopper looks. Every read below answered about it before the
# status shipped (docs/plans/6.0-seller-master-catalog-listings.md, Decision 3).
RSpec.describe 'variant status and shopper-facing visibility' do
  let(:store) { Spree::Store.default }
  let(:seller) { create(:seller, :approved, store: store) }
  let(:master) { create(:product, store: store, seller: nil, status: 'active') }

  # The marketplace's own row, so the product sells something either way and
  # the offer's absence is what the assertions isolate. The product factory
  # creates a default variant of its own, so this is the second first-party
  # row rather than the only one.
  let!(:first_party) do
    create(:variant, product: master, status: 'active').tap do |variant|
      variant.set_price('USD', 20)
      variant.set_stock(5, false, store.stock_locations.first)
    end
  end

  let!(:offer) do
    create(:variant, product: master, seller: seller, status: 'proposed').tap do |variant|
      variant.set_price('USD', 5)
      variant.set_stock(5, false, store.stock_locations.first)
    end
  end

  before { master.reload }

  describe 'availability' do
    it 'refuses an offer awaiting review' do
      expect(offer).not_to be_available
      expect(offer).not_to be_purchasable
    end

    %w[draft rejected archived].each do |status|
      it "refuses an offer that is #{status}" do
        offer.update!(status: status)

        expect(offer.reload).not_to be_available
      end
    end

    it 'allows one the marketplace approved' do
      offer.update!(status: 'active')

      expect(offer.reload).to be_available
    end

    # purchasable? reaches preorder? through oversellable_now?, which never
    # consulted available? — so a preorderable offer stayed buyable.
    it 'refuses a preorderable offer awaiting review' do
      offer.update!(preorderable: true, track_inventory: true)
      offer.set_stock(0, false, store.stock_locations.first)

      expect(offer.reload).not_to be_preorder
      expect(offer).not_to be_purchasable
    end
  end

  describe 'the product rollups' do
    # Both routes, because they are different code: the association narrows in
    # SQL, and `visible_variants` answers from the preloaded array so a
    # storefront listing pays no second query per product.
    it 'leaves an offer awaiting review out of the listed association' do
      expect(master.listed_variants).to include(first_party)
      expect(master.listed_variants).not_to include(offer)
    end

    it 'leaves it out of the in-memory reader too' do
      preloaded = Spree::Product.includes(:variants).find(master.id)

      expect(preloaded.variants).to be_loaded
      expect(preloaded.visible_variants).to include(first_party)
      expect(preloaded.visible_variants).not_to include(offer)
    end

    # The facet values a shopper is offered come through the same narrowing.
    it 'leaves its option values off the product' do
      size = create(:option_type, name: 'size', label: 'Size')
      only_on_offer = create(:option_value, option_type: size, name: 'xxl', label: 'XXL')
      offer.option_values << only_on_offer

      expect(master.reload.option_values).not_to include(only_on_offer)
    end

    it 'leaves it out of sellable_variants' do
      expect(master.sellable_variants).to include(first_party)
      expect(master.sellable_variants).not_to include(offer)
    end

    # The whole point of the buy box: it must never lead with a price nobody
    # approved, and a cheaper unapproved offer is exactly what would win.
    it 'never features it in the buy box, even when it is cheapest' do
      expect(master.buy_box_variant(currency: 'USD')).not_to eq(offer)
      expect(master.buy_box_variant(currency: 'USD').resolved_seller_id).to be_nil
    end

    it 'lets it compete once approved' do
      offer.update!(status: 'active')

      expect(master.reload.listed_variants).to include(offer)
      expect(master.sellable_variants).to include(offer)
    end

    # First-party outranks a seller whatever the price, so an approved offer
    # wins the buy box only once the marketplace is not selling it itself
    # (docs/plans/6.0-multi-vendor-marketplace.md, Decision 11).
    it 'wins the buy box once approved and nothing first-party is on sale' do
      offer.update!(status: 'active')
      master.variants.where(seller_id: nil).find_each { |variant| variant.update!(status: 'archived') }

      expect(master.reload.buy_box_variant(currency: 'USD')).to eq(offer)
    end
  end

  describe 'option filtering' do
    let(:size) { create(:option_type, name: 'size', label: 'Size') }
    let(:large) { create(:option_value, option_type: size, name: 'large', label: 'Large') }

    # A product must not surface in a filter through a row nobody approved:
    # the shopper clicks Large, lands on the product, and finds nothing large
    # they can buy.
    it 'does not match a product through an offer awaiting review' do
      offer.option_values << large
      master.option_types << size

      expect(Spree::Product.with_option_value_ids(large.id)).not_to include(master)
    end

    it 'matches once the offer is approved' do
      offer.option_values << large
      master.option_types << size
      offer.update!(status: 'active')

      expect(Spree::Product.with_option_value_ids(large.id)).to include(master)
    end
  end

  # A store selling only its own goods must notice none of this.
  describe 'a first-party catalog' do
    it 'creates variants active by default' do
      expect(create(:variant)).to be_active
    end

    it 'leaves an ordinary product purchasable' do
      product = create(:product, store: store)
      product.default_variant.set_stock(3, false, store.stock_locations.first)

      expect(product.reload).to be_purchasable
    end
  end
end
