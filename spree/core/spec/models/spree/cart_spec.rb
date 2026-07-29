require 'spec_helper'

describe Spree::Cart, type: :model do
  describe 'readonly after completion' do
    let(:cart) { create(:cart, store: @default_store) }

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
end
