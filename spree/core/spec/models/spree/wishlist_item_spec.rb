require 'spec_helper'

RSpec.describe Spree::WishlistItem, type: :model do
  it_behaves_like 'lifecycle events'

  describe '.quantity' do
    subject { build(:wishlist_item) }

    let!(:wishlist) { create(:wishlist) }
    let!(:variant) { create(:variant) }
    let!(:wishlist_item_with_variant) { create(:wishlist_item, variant: variant, quantity: 3) }

    it { is_expected.to respond_to(:quantity) }
    it { expect(subject.quantity).to eq(1) }

    it 'validates presence of wishlist' do
      expect(described_class.new(quantity: 3, wishlist: nil, variant: variant)).not_to be_valid
    end

    it 'validates presence of variant' do
      expect(described_class.new(quantity: 3, wishlist: wishlist, variant: nil)).not_to be_valid
    end

    it 'validates numericality of quantity' do
      expect(described_class.new(quantity: nil, wishlist: wishlist, variant: variant)).not_to be_valid
      expect(described_class.new(quantity: 'string', wishlist: wishlist, variant: variant)).not_to be_valid
      expect(described_class.new(quantity: 0.5, wishlist: wishlist, variant: variant)).not_to be_valid
    end

    it 'validates numericality must be greater than 0' do
      expect(described_class.new(quantity: 0, wishlist: wishlist, variant: variant)).not_to be_valid
      expect(described_class.new(quantity: -1, wishlist: wishlist, variant: variant)).not_to be_valid
    end

    describe 'when wishlist_item is already associated with the wishlist' do
      let!(:existing_wishlist_item) { create(:wishlist_item, quantity: 3, wishlist: wishlist, variant: variant) }

      it 'validates uniqueness of variant within scope of wishlist' do
        expect(described_class.new(quantity: 2, wishlist: wishlist, variant: variant)).not_to be_valid
      end
    end

    describe '.price' do
      it { expect(wishlist_item_with_variant.price(currency: 'USD')).to eq(variant.amount_in('USD')) }
    end

    describe '.total' do
      it { expect(wishlist_item_with_variant.total(currency: 'USD')).to eql(variant.amount_in('USD') * 3) }
    end

    describe '.display_price' do
      it { expect(wishlist_item_with_variant.display_price(currency: 'USD')).to eq Spree::Money.new(variant.amount_in('USD'), currency: 'USD') }
    end

    describe '.display_total' do
      it { expect(wishlist_item_with_variant.display_total(currency: 'USD')).to eq Spree::Money.new((variant.amount_in('USD') * 3), currency: 'USD') }
    end
  end

  describe 'the legacy Spree::WishedItem constant' do
    it 'resolves to this class' do
      expect(Spree::WishedItem).to be(described_class)
    end
  end

  # The rename would otherwise silently unsubscribe every webhook endpoint a
  # merchant had pointed at wished_item.*. Both names ship for one release.
  describe 'legacy wished_item events', events: true do
    let!(:wishlist_item) { create(:wishlist_item) }

    before do
      Spree::Events.reset!
      allow(Spree::Events).to receive(:enabled?).and_return(true)
    end

    after { Spree::Events.reset! }

    # One subscription set per example: calling this twice would count every
    # event twice over.
    def names_published
      received = []
      %w[wishlist_item wished_item].each do |prefix|
        %w[created updated deleted].each do |suffix|
          Spree::Events.subscribe("#{prefix}.#{suffix}", async: false) { |event| received << event.name }
        end
      end
      Spree::Events.activate!
      yield
      received
    end

    it 'publishes created under both names' do
      names = names_published { create(:wishlist_item) }

      expect(names).to contain_exactly('wishlist_item.created', 'wished_item.created')
    end

    it 'publishes updated under both names' do
      names = names_published { wishlist_item.update!(quantity: 3) }

      expect(names).to contain_exactly('wishlist_item.updated', 'wished_item.updated')
    end

    it 'publishes deleted under both names' do
      names = names_published { wishlist_item.destroy! }

      expect(names).to contain_exactly('wishlist_item.deleted', 'wished_item.deleted')
    end
  end

end
