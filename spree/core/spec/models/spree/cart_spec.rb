require 'spec_helper'

describe Spree::Cart, type: :model do
  let(:store) { @default_store }
  let(:customer) { create(:user) }

  describe 'lifecycle events' do
    it 'publishes cart.* lifecycle events' do
      expect(described_class.lifecycle_events_enabled).to be true
      expect(described_class.event_prefix).to eq('cart')

      registered = described_class._commit_callbacks.map(&:filter)
      expect(registered).to include(:publish_create_event, :publish_update_event, :publish_delete_event)
    end

    # The V3 cart serializer resolves by convention when spree_api is loaded;
    # core's dummy app only sees the fallback payload.
    it 'carries the prefixed id in the event payload' do
      cart = create(:cart, store: store)

      expect(cart.event_payload[:id]).to eq(cart.prefixed_id)
    end
  end

  describe 'readonly after completion' do
    let(:cart) { create(:cart, store: store) }

    it 'rejects every write path once completed' do
      cart.update_columns(completed_at: Time.current)

      reloaded = Spree::Cart.find(cart.id)
      expect(reloaded).to be_readonly
      expect { reloaded.update!(email: 'x@example.com') }.to raise_error(ActiveRecord::ReadOnlyRecord)
      expect { reloaded.update_columns(email: 'x@example.com') }.to raise_error(ActiveRecord::ReadOnlyRecord)
      expect { reloaded.touch }.to raise_error(ActiveRecord::ReadOnlyRecord)
      expect { reloaded.destroy }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end

    it 'lets the completion write through and locks the instance after it' do
      expect { cart.update_columns(completed_at: Time.current) }.not_to raise_error
      expect(cart).to be_readonly
    end
  end

  describe 'lifecycle' do
    it 'generates a token on create' do
      expect(create(:cart).token).to be_present
    end

    it 'is completed when completed_at is set' do
      expect(build(:cart, completed_at: Time.current)).to be_completed
      expect(build(:cart)).not_to be_completed
    end

    it 'is completing while completing_at holds the cart' do
      expect(build(:cart, completing_at: Time.current)).to be_completing
      expect(build(:cart)).not_to be_completing
    end

    it 'scopes complete/incomplete on completed_at' do
      incomplete = create(:cart)
      complete = create(:cart, completed_at: Time.current)

      expect(described_class.complete).to contain_exactly(complete)
      expect(described_class.incomplete).to contain_exactly(incomplete)
    end
  end

  describe 'line item ownership' do
    let(:cart) { create(:cart) }

    it 'owns line items and destroys them with the cart' do
      line_item = create(:line_item, order: nil, cart: cart, currency: cart.currency)

      expect(line_item.owner).to eq(cart)
      expect { cart.destroy }.to change(Spree::LineItem, :count).by(-1)
    end
  end

  describe 'order link' do
    it 'links to the order completed from it' do
      cart = create(:cart, completed_at: Time.current)
      order = create(:order, cart: cart)

      expect(cart.order).to eq(order)
    end
  end

  describe '#warnings' do
    let(:cart) { build(:cart) }

    it 'defaults to empty array' do
      expect(cart.warnings).to eq([])
    end

    it 'is a transient attribute (not persisted)' do
      cart.warnings = [{ code: 'test', message: 'test' }]
      cart.save!
      expect(cart.reload.warnings).to eq([])
    end
  end

  describe '#remove_out_of_stock_items!' do
    let(:cart) { create(:cart_with_line_items, store: store, customer: customer) }

    context 'when all items are in stock' do
      it 'does not remove any items' do
        expect { cart.remove_out_of_stock_items! }.not_to change { cart.line_items.count }
      end

      it 'sets warnings to empty array' do
        cart.remove_out_of_stock_items!
        expect(cart.warnings).to eq([])
      end
    end

    context 'when an item is out of stock' do
      before do
        cart.line_items.first.variant.stock_items.update_all(count_on_hand: 0, backorderable: false)
      end

      it 'removes the out of stock item' do
        expect { cart.remove_out_of_stock_items! }.to change { cart.reload.line_items.count }.by(-1)
      end

      it 'populates warnings with structured data' do
        cart.remove_out_of_stock_items!
        expect(cart.warnings.length).to eq(1)
        expect(cart.warnings.first[:code]).to eq('line_item_removed')
        expect(cart.warnings.first[:message]).to be_present
        expect(cart.warnings.first[:variant_id]).to start_with('variant_')
        expect(cart.warnings.first[:line_item_id]).to start_with('li_')
      end
    end

    context 'when a product is discontinued' do
      before do
        cart.line_items.first.product.update_columns(status: 'discontinued')
      end

      it 'removes the item and populates warnings' do
        cart.remove_out_of_stock_items!
        expect(cart.warnings.length).to eq(1)
        expect(cart.warnings.first[:code]).to eq('line_item_removed')
      end
    end

    context 'when cart is empty' do
      let(:order) { create(:order, store: store, user: user) }

      it 'does nothing' do
        cart.remove_out_of_stock_items!
        expect(cart.warnings).to eq([])
      end
    end
  end
end
