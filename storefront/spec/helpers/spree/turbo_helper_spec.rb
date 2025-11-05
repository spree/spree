require 'spec_helper'

RSpec.describe Spree::TurboHelper, type: :helper do
  let(:order) { create(:order_with_line_items) }
  let(:empty_order) { create(:order) }

  describe '#spree_turbo_update_cart' do
    context 'with order containing items' do
      before do
        allow(order).to receive(:item_count).and_return(3)
        allow(order).to receive(:display_item_total).and_return(double(to_s: '$30.00'))
      end

      it 'returns turbo stream updates for cart counter and total' do
        result = helper.spree_turbo_update_cart(order)

        expect(result).to include('turbo-stream action="update" targets=".cart-counter"')
        expect(result).to include('<template>3</template>')
        expect(result).to include('turbo-stream action="update" targets=".cart-total"')
        expect(result).to include('<template>$30.00</template>')
      end
    end

    context 'with empty order' do
      before do
        allow(empty_order).to receive(:item_count).and_return(0)
        allow(empty_order).to receive(:display_item_total).and_return(double(to_s: '$0.00'))
      end

      it 'returns empty string for cart counter when no items' do
        result = helper.spree_turbo_update_cart(empty_order)

        expect(result).to include('turbo-stream action="update" targets=".cart-counter"')
        expect(result).to include('<template></template>')
        expect(result).to include('turbo-stream action="update" targets=".cart-total"')
        expect(result).to include('<template>$0.00</template>')
      end
    end

    context 'with nil order' do
      it 'handles nil order gracefully' do
        result = helper.spree_turbo_update_cart(nil)

        expect(result).to include('turbo-stream action="update" targets=".cart-counter"')
        expect(result).to include('<template></template>')
        expect(result).to include('turbo-stream action="update" targets=".cart-total"')
        expect(result).to include('<template></template>')
      end
    end

    context 'when no order is passed' do
      before do
        allow(helper).to receive(:current_order).and_return(order)
        allow(order).to receive(:item_count).and_return(2)
        allow(order).to receive(:display_item_total).and_return(double(to_s: '$20.00'))
      end

      it 'uses current_order as default' do
        result = helper.spree_turbo_update_cart

        expect(result).to include('turbo-stream action="update" targets=".cart-counter"')
        expect(result).to include('<template>2</template>')
        expect(result).to include('turbo-stream action="update" targets=".cart-total"')
        expect(result).to include('<template>$20.00</template>')
      end
    end

    it 'returns html_safe string' do
      result = helper.spree_turbo_update_cart(order)

      expect(result).to be_html_safe
    end
  end
end
