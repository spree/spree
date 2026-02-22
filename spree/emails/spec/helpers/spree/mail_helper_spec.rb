require 'spec_helper'

module Spree
  describe MailHelper, type: :helper do
    let(:store) { @default_store }

    before do
      allow(helper).to receive(:current_store) { store }
    end

    describe '#variant_image_url' do
      subject { helper.variant_image_url(variant) }

      let(:product) { create(:product, stores: [store]) }
      let(:variant) { create(:variant, product: product, images: images) }

      context 'with no images' do
        let(:images) { [] }

        specify 'returns placeholder path' do
          expect(subject).to match Regexp.new('assets/noimage/small-[0-9a-z]*\.png')
        end
      end

      context 'with images' do
        let(:images) { [image] }
        let(:image) { create(:image) }

        specify 'returns proper image path' do
          expect(subject).to eq spree_image_url(image, variant: :mini)
        end
      end
    end

    describe '#name_for' do
      subject { helper.name_for(order) }

      let(:order) { create(:order, ship_address_id: nil, bill_address_id: nil, store: store) }
      let(:address) { create(:address) }

      context 'without address' do
        it 'shows default name' do
          expect(subject).to eq Spree.t('customer')
        end
      end

      context 'with address' do
        before do
          order.update(ship_address: address)
        end

        it 'shows customer full name' do
          expect(subject).to eq address.full_name
        end
      end
    end
  end
end
