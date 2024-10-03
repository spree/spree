require 'spec_helper'

describe Spree::Admin::PaymentsHelper, type: :helper do
  let!(:store) { create(:store) }

  before do
    allow(helper).to receive(:current_store).and_return(store)
  end

  describe '#payment_source_name' do
    let(:payment_method) { create(:credit_card_payment_method, stores: [store]) }
    let(:payment) { build(:payment, payment_method: payment_method) }

    before do
      allow(payment).to receive(:source).and_return(source)
    end

    context 'for source with display_name' do
      let(:source) { double('Payment Source', class: double('Payment Source Class', display_name: 'Display 554')) }

      it 'returns the display name of the source class' do
        expect(helper.payment_source_name(payment)).to eq('Display 554')
      end
    end

    context 'for source without display_name' do
      let(:source) { double('Payment Source', class: double('Payment Source Class', name: 'MyPaymentMethod')) }

      it 'returns the display name of the source class' do
        expect(helper.payment_source_name(payment)).to eq('My Payment Method')
      end
    end
  end
end
