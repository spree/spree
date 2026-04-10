require 'spec_helper'

module Spree
  describe Cart::Update do
    subject { described_class }

    let(:order) { create(:order) }
    let(:variant) { create(:variant) }
    let!(:line_item) { Spree::Cart::AddItem.call(order: order, variant: variant, quantity: 1).value }

    let(:execute) { subject.call(order: order, params: params) }

    context 'with Hash form line_items_attributes (legacy)' do
      let(:params) do
        { line_items_attributes: { '0' => { id: line_item.id, quantity: 3 } } }
      end

      it 'updates line item quantity' do
        expect(execute).to be_success
        expect(line_item.reload.quantity).to eq 3
      end
    end

    context 'with Hash form containing a nonexistent id' do
      let(:params) do
        {
          line_items_attributes: {
            '0' => { id: line_item.id, quantity: 0 },
            '1' => { id: '666', quantity: 0 }
          }
        }
      end

      it 'filters out the nonexistent id and does not raise' do
        expect { execute }.not_to raise_error
        expect(execute).to be_success
      end
    end

    context 'with id-only Hash shortcut (single line item)' do
      let(:params) do
        { line_items_attributes: { id: line_item.id, quantity: 2 } }
      end

      it 'passes through and updates the line item' do
        expect(execute).to be_success
        expect(line_item.reload.quantity).to eq 2
      end
    end

    context 'with Array form line_items_attributes (Issue #9718)' do
      let(:params) do
        { line_items_attributes: [{ id: line_item.id, quantity: 4 }] }
      end

      it 'does not raise TypeError and updates the line item' do
        expect { execute }.not_to raise_error
        expect(execute).to be_success
        expect(line_item.reload.quantity).to eq 4
      end
    end

    context 'with Array form containing a nonexistent id' do
      let(:params) do
        {
          line_items_attributes: [
            { id: line_item.id, quantity: 5 },
            { id: '666', quantity: 2 }
          ]
        }
      end

      it 'filters out the nonexistent id and updates the valid one' do
        expect { execute }.not_to raise_error
        expect(execute).to be_success
        expect(line_item.reload.quantity).to eq 5
      end
    end

    context 'with Array form containing a new variant_id' do
      let(:new_variant) { create(:variant) }
      let(:params) do
        { line_items_attributes: [{ variant_id: new_variant.id, quantity: 2 }] }
      end

      it 'keeps entries with variant_id even when id is absent' do
        expect { execute }.not_to raise_error
        expect(execute).to be_success
      end
    end

    context 'with ActionController::Parameters wrapping Array' do
      let(:params) do
        ActionController::Parameters.new(
          line_items_attributes: [{ id: line_item.id, quantity: 6 }]
        ).permit(line_items_attributes: [:id, :quantity, :variant_id])
      end

      it 'does not raise and updates the line item' do
        expect { execute }.not_to raise_error
        expect(execute).to be_success
        expect(line_item.reload.quantity).to eq 6
      end
    end

    context 'with nil line_items_attributes' do
      let(:params) { { email: 'test@example.com' } }

      it 'does not raise and returns success' do
        expect { execute }.not_to raise_error
        expect(execute).to be_success
      end
    end
  end
end
