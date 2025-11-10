require 'spec_helper'

describe Spree::ProductsHelper, type: :helper do
  let(:store) { create(:store) }
  let(:zone) { create(:zone) }
  let(:user) { create(:user) }
  let(:variant) { create(:variant) }
  let(:product) { variant.product }
  let(:order) { create(:order, store: store, user: user) }
  let(:currency) { 'USD' }

  before do
    allow(helper).to receive(:current_store).and_return(store)
    allow(helper).to receive(:current_currency).and_return(currency)
    allow(helper).to receive(:try_spree_current_user).and_return(user)
    allow(helper).to receive(:current_order).and_return(order)
  end

  describe '#pricing_context_for_variant' do
    context 'with a variant' do
      it 'builds a pricing context with default values' do
        context = helper.pricing_context_for_variant(variant)

        expect(context).to be_a(Spree::Pricing::Context)
        expect(context.variant).to eq(variant)
        expect(context.currency).to eq(currency)
        expect(context.store).to eq(store)
        expect(context.user).to eq(user)
        expect(context.order).to eq(order)
      end

      it 'uses order.tax_zone when available' do
        order.update(ship_address: create(:address))
        tax_zone = create(:zone)
        allow(order).to receive(:tax_zone).and_return(tax_zone)

        context = helper.pricing_context_for_variant(variant)

        expect(context.zone).to eq(tax_zone)
      end

      it 'falls back to store.checkout_zone when order has no tax_zone' do
        allow(order).to receive(:tax_zone).and_return(nil)
        allow(store).to receive(:checkout_zone).and_return(zone)

        context = helper.pricing_context_for_variant(variant)

        expect(context.zone).to eq(zone)
      end
    end

    context 'with a product' do
      it 'builds a pricing context using the default variant' do
        context = helper.pricing_context_for_variant(product)

        expect(context).to be_a(Spree::Pricing::Context)
        expect(context.variant).to eq(product.default_variant)
      end
    end

    context 'with custom options' do
      let(:custom_currency) { 'EUR' }
      let(:custom_store) { create(:store) }
      let(:custom_zone) { create(:zone) }
      let(:custom_user) { create(:user) }
      let(:custom_order) { create(:order) }
      let(:custom_quantity) { 5 }
      let(:custom_date) { Time.current }

      it 'overrides default values with provided options' do
        context = helper.pricing_context_for_variant(
          variant,
          currency: custom_currency,
          store: custom_store,
          zone: custom_zone,
          user: custom_user,
          order: custom_order,
          quantity: custom_quantity,
          date: custom_date
        )

        expect(context.variant).to eq(variant)
        expect(context.currency).to eq(custom_currency)
        expect(context.store).to eq(custom_store)
        expect(context.zone).to eq(custom_zone)
        expect(context.user).to eq(custom_user)
        expect(context.order).to eq(custom_order)
        expect(context.quantity).to eq(custom_quantity)
        expect(context.date).to eq(custom_date)
      end

      it 'allows partial overrides' do
        context = helper.pricing_context_for_variant(
          variant,
          quantity: custom_quantity
        )

        expect(context.variant).to eq(variant)
        expect(context.currency).to eq(currency)
        expect(context.store).to eq(store)
        expect(context.user).to eq(user)
        expect(context.quantity).to eq(custom_quantity)
      end
    end
  end

  describe '#should_display_compare_at_price?' do
    let(:variant) { create(:variant, price: 10, compare_at_price: 15) }

    before do
      allow(helper).to receive(:current_order).and_return(nil)
      allow(store).to receive(:checkout_zone).and_return(zone)
    end

    context 'when compare_at_price is greater than price' do
      it 'returns true' do
        expect(helper.should_display_compare_at_price?(variant)).to be true
      end
    end

    context 'when compare_at_price is not present' do
      before { variant.update(compare_at_price: nil) }

      it 'returns false' do
        expect(helper.should_display_compare_at_price?(variant)).to be false
      end
    end

    context 'when compare_at_price is less than or equal to price' do
      before { variant.update(compare_at_price: 8) }

      it 'returns false' do
        expect(helper.should_display_compare_at_price?(variant)).to be false
      end
    end

    context 'with a product' do
      it 'uses the default variant' do
        expect(helper.should_display_compare_at_price?(product)).to be true
      end
    end
  end
end
