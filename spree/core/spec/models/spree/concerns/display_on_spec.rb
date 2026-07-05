# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::DisplayOn do
  # PaymentMethod is the simplest factory-backed host; ShippingMethod
  # and MetafieldDefinition include the concern identically and inherit
  # this behaviour.
  let(:payment_method) { build(:check_payment_method) }

  describe '#storefront_visible' do
    it 'returns false when display_on is back_end' do
      payment_method.display_on = 'back_end'
      expect(payment_method.storefront_visible).to be false
    end

    it 'returns true when display_on is both' do
      payment_method.display_on = 'both'
      expect(payment_method.storefront_visible).to be true
    end

    it 'returns true for the legacy front_end-only value' do
      payment_method.display_on = 'front_end'
      expect(payment_method.storefront_visible).to be true
    end
  end

  describe '#storefront_visible=' do
    it 'maps true to display_on=both' do
      payment_method.storefront_visible = true
      expect(payment_method.display_on).to eq('both')
    end

    it 'maps false to display_on=back_end' do
      payment_method.storefront_visible = false
      expect(payment_method.display_on).to eq('back_end')
    end

    it 'coerces truthy strings to true (form payloads)' do
      payment_method.storefront_visible = '1'
      expect(payment_method.display_on).to eq('both')
    end

    it 'coerces falsy strings to false (form payloads)' do
      payment_method.storefront_visible = '0'
      expect(payment_method.display_on).to eq('back_end')
    end

    it 'round-trips: getter returns what setter set' do
      payment_method.storefront_visible = false
      expect(payment_method.storefront_visible).to be false

      payment_method.storefront_visible = true
      expect(payment_method.storefront_visible).to be true
    end
  end

  describe 'scopes' do
    let!(:storefront_method) { create(:check_payment_method, display_on: 'both') }
    let!(:admin_only_method) { create(:check_payment_method, display_on: 'back_end') }

    describe '.storefront_visible' do
      it 'returns methods where display_on != back_end' do
        expect(Spree::PaymentMethod.storefront_visible).to include(storefront_method)
        expect(Spree::PaymentMethod.storefront_visible).not_to include(admin_only_method)
      end
    end

    describe '.admin_only' do
      it 'returns methods where display_on == back_end' do
        expect(Spree::PaymentMethod.admin_only).to include(admin_only_method)
        expect(Spree::PaymentMethod.admin_only).not_to include(storefront_method)
      end
    end
  end
end
