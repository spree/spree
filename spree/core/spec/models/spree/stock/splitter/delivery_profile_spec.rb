require 'spec_helper'

module Spree
  module Stock
    module Splitter
      describe DeliveryProfile, type: :model do
        subject(:result) { described_class.new(packer).split([package]) }

        let(:store) { @default_store }
        let(:packer) { build(:stock_packer) }
        let(:package) { Package.new(packer.stock_location) }

        let(:standard) { create(:delivery_profile, store: store) }
        let(:oversized) { create(:delivery_profile, store: store) }

        it 'keeps one package per profile' do
          product = create(:product, store: store, delivery_profile: standard)
          a = create(:variant, product: product)
          b = create(:variant, product: product, delivery_profile: oversized)

          package.add_multiple(build_list(:inventory_unit, 1, :without_assoc, variant: a))
          package.add_multiple(build_list(:inventory_unit, 1, :without_assoc, variant: b))

          expect(result.size).to eq(2)
          expect(result.map(&:delivery_profile)).to contain_exactly(standard, oversized)
        end

        it 'keeps variants sharing a profile in one package' do
          product = create(:product, store: store, delivery_profile: standard)
          a = create(:variant, product: product)
          b = create(:variant, product: product)

          package.add_multiple(build_list(:inventory_unit, 1, :without_assoc, variant: a))
          package.add_multiple(build_list(:inventory_unit, 1, :without_assoc, variant: b))

          expect(result.size).to eq(1)
        end

        # The memoisation used to be keyed on product_id, so the second seller
        # on a shared product was packed and priced with the first seller's
        # shipping configuration.
        it 'does not give one seller another seller\'s shipping configuration' do
          seller = create(:seller, :approved, store: store)
          other_seller = create(:seller, :approved, store: store)
          product = create(:product, store: store, delivery_profile: standard)

          mine = create(:variant, product: product, seller: seller, delivery_profile: standard)
          theirs = create(:variant, product: product, seller: other_seller, delivery_profile: oversized)

          package.add_multiple(build_list(:inventory_unit, 1, :without_assoc, variant: mine))
          package.add_multiple(build_list(:inventory_unit, 1, :without_assoc, variant: theirs))

          expect(result.size).to eq(2)
          expect(result.map(&:delivery_profile)).to contain_exactly(standard, oversized)
        end
      end
    end
  end
end
