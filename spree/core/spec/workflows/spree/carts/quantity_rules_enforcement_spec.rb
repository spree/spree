require 'spec_helper'

# The purchasing layer end to end: what the workflows refuse, what they let
# through, and who is exempt.
RSpec.describe 'cart quantity rule enforcement' do
  let(:store) { @default_store }
  let(:product) { create(:product, store: store, price: 10) }
  let(:variant) { product.default_variant }
  let(:cart) { create(:cart, store: store) }

  before { variant.update!(minimum_order_quantity: 48, order_multiple: 24) }

  describe Spree::Carts::AddItem do
    it 'refuses a quantity below the minimum and names the valid ones' do
      result = described_class.call(cart: cart, variant: variant, quantity: 10)

      expect(result).to be_failure
      expect(result.error.to_s).to include('48')
      expect(cart.reload.line_items).to be_empty
    end

    it 'refuses a quantity off the multiple, offering both neighbours' do
      result = described_class.call(cart: cart, variant: variant, quantity: 60)

      expect(result).to be_failure
      expect(result.error.to_s).to include('48')
      expect(result.error.to_s).to include('72')
    end

    it 'accepts a valid quantity' do
      expect(described_class.call(cart: cart, variant: variant, quantity: 72)).to be_success
    end

    # An add is an increment, so what matters is where the line ends up.
    it 'judges the resulting line quantity, not the increment' do
      described_class.call(cart: cart, variant: variant, quantity: 48)

      result = described_class.call(cart: cart, variant: variant, quantity: 24)

      expect(result).to be_success
      expect(cart.reload.line_items.first.quantity).to eq(72)
    end

    it 'refuses an increment that lands the line off the multiple' do
      described_class.call(cart: cart, variant: variant, quantity: 48)

      expect(described_class.call(cart: cart, variant: variant, quantity: 5)).to be_failure
      expect(cart.reload.line_items.first.quantity).to eq(48)
    end

    it 'leaves a variant with no rules alone' do
      variant.update!(minimum_order_quantity: nil, order_multiple: nil)

      expect(described_class.call(cart: cart, variant: variant, quantity: 7)).to be_success
    end

    # The admin surface is a draft order, not a cart — a cart is always the
    # buyer's own.
    it 'lets staff key in whatever the buyer negotiated on a draft order' do
      draft = create(:order, store: store)

      expect(described_class.call(cart: draft, variant: variant, quantity: 5)).to be_success
    end
  end

  describe Spree::Carts::UpsertItems do
    it 'warns about a line it will not apply rather than failing the batch' do
      other = create(:product, store: store, price: 5).default_variant

      result = described_class.call(cart: cart, items: [
        { variant_id: variant.id, quantity: 10 },
        { variant_id: other.id, quantity: 3 }
      ])

      expect(result).to be_success
      # Warnings ride on the returned cart; reading them before touching the
      # record matters, because a reload drops them.
      expect(result.value.warnings.map { |warning| warning[:code] }).to include('quantity_rule_violated')
      expect(cart.reload.line_items.map(&:variant)).to eq([other])
    end

    it 'applies a valid quantity' do
      result = described_class.call(cart: cart, items: [{ variant_id: variant.id, quantity: 96 }])

      expect(result).to be_success
      expect(cart.reload.line_items.first.quantity).to eq(96)
    end

    # This workflow sets rather than increments, so a quantity edit down to an
    # invalid number is refused too.
    it 'refuses a quantity edit that breaks the rule' do
      described_class.call(cart: cart, items: [{ variant_id: variant.id, quantity: 96 }])

      described_class.call(cart: cart, items: [{ variant_id: variant.id, quantity: 30 }])

      expect(cart.reload.line_items.first.quantity).to eq(96)
    end

    # A buyer must always be able to empty a line, whatever the rules now say
    # about holding one.
    it 'always allows a removal' do
      described_class.call(cart: cart, items: [{ variant_id: variant.id, quantity: 96 }])
      variant.update!(minimum_order_quantity: 1000)

      described_class.call(cart: cart, items: [{ variant_id: variant.id, quantity: 0 }])

      expect(cart.reload.line_items).to be_empty
    end
  end

  describe Spree::Checkout::DefaultRequirements do
    let(:requirements) { described_class.new(cart.reload).call(completion: true) }

    before do
      Spree::Carts::AddItem.call(cart: cart, variant: variant, quantity: 48)
    end

    it 'says nothing while the line still satisfies its rules' do
      expect(requirements.map { |r| r[:code] }).not_to include('quantity_rule_violated')
    end

    # Terms can change under a buyer between the add and the checkout.
    it 'refuses a line the rules no longer admit' do
      variant.update!(minimum_order_quantity: 100, order_multiple: 100)

      violation = requirements.detect { |r| r[:code] == 'quantity_rule_violated' }

      expect(violation).to be_present
      expect(violation[:message]).to include('100')
    end

    it 'exempts a staff-keyed purchase' do
      allow(cart).to receive(:created_by_id).and_return(1)
      variant.update!(minimum_order_quantity: 100, order_multiple: 100)

      expect(requirements.map { |r| r[:code] }).not_to include('quantity_rule_violated')
    end
  end
end
