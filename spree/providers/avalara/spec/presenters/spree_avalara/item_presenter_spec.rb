require 'spec_helper'

RSpec.describe SpreeAvalara::ItemPresenter do
  let(:cart) { create(:cart, store: @default_store) }
  let(:line_item) { create(:line_item, cart: cart, order: nil, price: 25, quantity: 2) }

  def present(item, tax_included: false)
    described_class.new(item: item, owner: cart, tax_included: tax_included).call
  end

  describe 'a line item' do
    it 'is identified by its prefixed id and priced at its taxable basis' do
      payload = present(line_item)

      expect(payload[:number]).to eq(line_item.prefixed_id)
      expect(payload[:quantity]).to eq(2)
      expect(payload[:amount]).to eq(line_item.taxable_basis)
    end

    # The basis already has order-level promotions distributed into it, so
    # telling Avalara to discount the line again would take it twice.
    it 'never asks Avalara to discount the line' do
      payload = present(line_item)

      expect(payload[:discount]).to eq(0)
      expect(payload[:discounted]).to be(false)
    end

    it 'passes the resolved inclusiveness through' do
      expect(present(line_item, tax_included: true)[:taxIncluded]).to be(true)
      expect(present(line_item)[:taxIncluded]).to be(false)
    end

    # Classification lives on the variant; the line copies it on every save.
    it 'sends the item tax category code when the merchant classified the product' do
      category = create(:tax_category, store: @default_store, tax_code: 'PC040100')
      line_item.variant.update!(tax_category: category)
      line_item.save!

      expect(present(line_item.reload)[:taxCode]).to eq('PC040100')
    end

    it "falls back to the store default category's code" do
      create(:tax_category, store: @default_store, tax_code: 'PC030000', is_default: true)

      expect(present(line_item)[:taxCode]).to eq('PC030000')
    end

    # A category with no Avalara code classifies nothing as far as AvaTax is
    # concerned, which is the common case for a store that never set one.
    it 'falls back to generic tangible goods when no category carries a code' do
      expect(line_item.tax_category&.tax_code).to be_blank

      expect(present(line_item)[:taxCode]).to eq(described_class::DEFAULT_TAX_CODE)
    end
  end

  describe 'a fulfillment' do
    let(:fulfillment) { create(:fulfillment, cart: cart, order: nil) }

    # A fulfillment carries no tax category of its own; the delivery method it
    # was rated with does.
    it 'is taxed as freight when the delivery method names no category' do
      expect(present(fulfillment)[:taxCode]).to eq(described_class::FREIGHT_TAX_CODE)
    end

    it 'ships from its own stock location' do
      expect(present(fulfillment)[:addresses][:shipFrom]).to include(
        country: fulfillment.stock_location.country_code
      )
    end
  end

  describe 'a fee' do
    let(:fee) { create(:fee, cart: cart, order: nil, amount: 7.5) }

    it 'is priced at its amount' do
      expect(present(fee)[:amount]).to eq(7.5)
      expect(present(fee)[:quantity]).to eq(1)
    end

    # Parity with the Internal engine, which taxes a category-less fee with the
    # store default; with no default there is nothing to claim, so the key goes.
    it 'omits the tax code when the store has no default category' do
      expect(present(fee)).not_to have_key(:taxCode)
    end

    it "uses the store default category's code when there is one" do
      create(:tax_category, store: @default_store, tax_code: 'OF040000', is_default: true)

      expect(present(fee)[:taxCode]).to eq('OF040000')
    end
  end
end
