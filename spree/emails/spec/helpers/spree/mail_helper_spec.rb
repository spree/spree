require 'spec_helper'

module Spree
  describe MailHelper, type: :helper do
    let(:store) { @default_store }

    before do
      allow(helper).to receive(:current_store) { store }
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
