require 'spec_helper'

RSpec.describe Spree::V2::Storefront::CartSerializer do
  subject { described_class.new(order).serializable_hash }

  include_context 'API v2 serializers params'

  let!(:order) { create(:order) }

  describe '#promo_total_cents' do
    context 'without any promo applied' do
      it 'returns 0 promo total' do
        expect(subject[:data][:attributes][:promo_total_cents]).to eq(0)
      end
    end

    context 'with a promo applied' do
      before do
        order.update_column(:promo_total, 10)
      end

      it 'returns the promo total in cents' do
        expect(subject[:data][:attributes][:promo_total_cents]).to eq(1000)
      end
    end
  end
end
