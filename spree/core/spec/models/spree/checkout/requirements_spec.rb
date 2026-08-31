require 'spec_helper'

RSpec.describe Spree::Checkout::Requirements do
  after { Spree::Checkout::Registry.reset! }

  let(:store) { create(:store) }
  let(:order) { create(:order, store: store) }

  subject { described_class.new(order).call }

  describe 'line items requirement' do
    it 'requires line_items when cart is empty' do
      expect(subject).to include(
        a_hash_including(step: 'cart', field: 'line_items')
      )
    end

    it 'does not require line_items when cart has items' do
      create(:line_item, order: order)
      order.reload

      expect(subject).not_to include(
        a_hash_including(step: 'cart', field: 'line_items')
      )
    end
  end

  describe 'email requirement' do
    it 'requires email when not set' do
      order.update_column(:email, nil)
      order.reload

      expect(subject).to include(
        a_hash_including(step: 'address', field: 'email')
      )
    end

    it 'does not require email when set' do
      order.update_column(:email, 'test@example.com')
      order.reload

      expect(subject).not_to include(
        a_hash_including(step: 'address', field: 'email')
      )
    end
  end

  describe 'ship_address requirement' do
    it 'requires ship_address for physical orders without address' do
      allow(order).to receive(:shipping_address_required?).and_return(true)
      order.ship_address = nil

      expect(subject).to include(
        a_hash_including(step: 'address', field: 'ship_address')
      )
    end

    it 'does not require ship_address for digital orders' do
      allow(order).to receive(:shipping_address_required?).and_return(false)

      expect(subject).not_to include(
        a_hash_including(step: 'address', field: 'ship_address')
      )
    end
  end

  describe 'shipping_method requirement' do
    let(:order) { create(:order_with_line_items, store: store) }

    it 'requires shipping_method when delivery step exists and no shipments have methods' do
      allow(order).to receive(:has_checkout_step?).with('delivery').and_return(true)
      allow(order).to receive(:has_checkout_step?).with('payment').and_return(true)
      allow(order).to receive(:delivery_step_required?).and_return(true)
      order.shipments.destroy_all

      expect(subject).to include(
        a_hash_including(step: 'delivery', field: 'delivery_method')
      )
    end

    it 'does not require shipping_method when no delivery step' do
      allow(order).to receive(:has_checkout_step?).with('delivery').and_return(false)
      allow(order).to receive(:has_checkout_step?).with('payment').and_return(true)

      expect(subject).not_to include(
        a_hash_including(step: 'delivery', field: 'delivery_method')
      )
    end
  end

  describe 'payment requirement' do
    let(:order) { create(:order_with_line_items, store: store) }

    it 'requires payment when payment is required and no valid payments' do
      allow(order).to receive(:has_checkout_step?).with('delivery').and_return(true)
      allow(order).to receive(:has_checkout_step?).with('payment').and_return(true)
      allow(order).to receive(:payment_required?).and_return(true)

      expect(subject).to include(
        a_hash_including(step: 'payment', field: 'payment')
      )
    end

    it 'does not require payment for free orders' do
      allow(order).to receive(:has_checkout_step?).with('delivery').and_return(true)
      allow(order).to receive(:has_checkout_step?).with('payment').and_return(true)
      allow(order).to receive(:payment_required?).and_return(false)

      expect(subject).not_to include(
        a_hash_including(step: 'payment', field: 'payment')
      )
    end
  end

  describe 'po_number requirement' do
    let(:customer) { create(:user) }
    let(:company) { create(:company, store: store, po_number_required: true) }

    before do
      create(:company_membership, company: company, customer: customer)
      order.update_columns(customer_id: customer.id, company_id: company.id)
      order.reload
    end

    it 'asks for the reference when the buyer\'s company demands one' do
      expect(subject).to include(
        a_hash_including(step: 'payment', field: 'po_number', code: 'po_number_required')
      )
    end

    it 'stops asking once the buyer supplies it' do
      order.update!(po_number: 'PO-4471')

      expect(subject).not_to include(a_hash_including(field: 'po_number'))
    end

    it 'does not ask when the company does not demand one' do
      company.update!(po_number_required: false)
      order.reload

      expect(subject).not_to include(a_hash_including(field: 'po_number'))
    end

    it 'does not ask of staff keying the order in' do
      order.update_columns(created_by_id: create(:admin_user).id)
      order.reload

      expect(subject).not_to include(a_hash_including(field: 'po_number'))
    end
  end

  describe 'fully ready order' do
    let(:order) { create(:order_with_line_items, store: store, state: 'payment') }

    before do
      create(:payment, amount: order.total, order: order)
      order.reload
    end

    it 'returns empty array' do
      expect(subject).to eq([])
    end
  end

  describe 'custom registered step' do
    it 'includes requirements from unsatisfied applicable steps' do
      Spree::Checkout::Registry.register_step(
        name: :custom,
        satisfied: ->(_order) { false },
        requirements: ->(_order) { [{ step: 'custom', field: 'custom_field', message: 'Custom required' }] },
        applicable: ->(_order) { true }
      )

      expect(subject).to include(
        a_hash_including(step: 'custom', field: 'custom_field', message: 'Custom required')
      )
    end

    it 'excludes requirements from satisfied steps' do
      Spree::Checkout::Registry.register_step(
        name: :custom,
        satisfied: ->(_order) { true },
        requirements: ->(_order) { [{ step: 'custom', field: 'custom_field', message: 'Custom required' }] }
      )

      expect(subject).not_to include(
        a_hash_including(step: 'custom', field: 'custom_field')
      )
    end

    it 'excludes requirements from non-applicable steps' do
      Spree::Checkout::Registry.register_step(
        name: :custom,
        satisfied: ->(_order) { false },
        requirements: ->(_order) { [{ step: 'custom', field: 'custom_field', message: 'Custom required' }] },
        applicable: ->(_order) { false }
      )

      expect(subject).not_to include(
        a_hash_including(step: 'custom', field: 'custom_field')
      )
    end
  end

  describe 'custom additional requirement' do
    it 'includes unsatisfied applicable requirements' do
      Spree::Checkout::Registry.add_requirement(
        step: :payment,
        field: :po_number,
        message: 'PO number is required for B2B',
        satisfied: ->(_order) { false },
        applicable: ->(_order) { true }
      )

      expect(subject).to include(
        a_hash_including(step: 'payment', field: 'po_number', message: 'PO number is required for B2B')
      )
    end

    it 'excludes satisfied requirements' do
      Spree::Checkout::Registry.add_requirement(
        step: :payment,
        field: :po_number,
        message: 'PO number is required for B2B',
        satisfied: ->(_order) { true }
      )

      expect(subject).not_to include(
        a_hash_including(step: 'payment', field: 'po_number')
      )
    end

    it 'excludes non-applicable requirements' do
      Spree::Checkout::Registry.add_requirement(
        step: :payment,
        field: :po_number,
        message: 'PO number is required for B2B',
        satisfied: ->(_order) { false },
        applicable: ->(_order) { false }
      )

      expect(subject).not_to include(
        a_hash_including(step: 'payment', field: 'po_number')
      )
    end
  end

  describe '#met?' do
    it 'returns false when requirements exist' do
      expect(described_class.new(order).met?).to be false
    end

    it 'returns true when all requirements are met' do
      order = create(:order_with_line_items, store: store, state: 'payment')
      create(:payment, amount: order.total, order: order)
      order.reload
      expect(described_class.new(order).met?).to be true
    end
  end
end
