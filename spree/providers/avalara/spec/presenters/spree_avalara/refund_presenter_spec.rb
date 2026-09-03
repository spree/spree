require 'spec_helper'

RSpec.describe SpreeAvalara::RefundPresenter do
  let(:integration) { build(:avalara_integration, store: @default_store, preferred_company_code: 'SPARK') }
  let(:order) { create(:order, store: @default_store, completed_at: Time.utc(2026, 5, 1, 12, 0, 0)) }
  let(:line_item) { create(:line_item, order: order, cart: nil, price: 100, quantity: 4) }

  # Four units worth 400 before tax, so a unit credits 100.
  before { line_item.update_column(:pre_tax_amount, 400) }

  def return_item(received: 2)
    instance_double(
      Spree::ReturnLineItem,
      line_item: line_item,
      received_quantity: received,
      return: instance_double(Spree::Return, number: 'RET1')
    )
  end

  def present(**overrides)
    described_class.new(**{ order: order, integration: integration, return_items: [return_item] }.merge(overrides))
  end

  it 'credits the returned units at their pre-tax worth' do
    expect(present.lines_worth).to eq(200)
    expect(present.call[:lines].sole).to include(number: line_item.prefixed_id, quantity: 2, amount: -200)
  end

  it 'files a line-level return rather than a percentage refund' do
    payload = present.call

    expect(payload[:type]).to eq('ReturnInvoice')
    expect(payload[:companyCode]).to eq('SPARK')
    expect(payload[:lines].map { |line| line[:amount] }).to all(be_negative)
  end

  # The same merchant preference governs the credit, so a store filing sales
  # uncommitted files its credits the same way.
  it 'files the credit with the status the merchant chose' do
    expect(present.call[:commit]).to be(true)

    integration.preferred_commit_transaction_enabled = false

    expect(present.call[:commit]).to be(false)
  end

  # A replayed Returns::Refund must adjust this document, not file a second credit.
  it 'keys the document to the order and the return' do
    expect(present.code).to eq("#{order.number}-RET1")
  end

  # Rates move, and a return reverses the original sale rather than making a new one.
  it 'taxes the credit as of the original supply date' do
    expect(present.call[:taxOverride]).to eq(type: 'TaxDate', reason: 'Refund', taxDate: '2026-05-01')
  end

  # The credit has to be classified the way the sale was, or Avalara re-prices it
  # as generic goods for a non-exempt buyer.
  describe 'mirroring the sale' do
    it 'carries the tax code the line was sold under' do
      category = create(:tax_category, store: @default_store, tax_code: 'PC040100')
      line_item.variant.update!(tax_category: category)
      line_item.save!

      expect(present.call[:lines].sole[:taxCode]).to eq('PC040100')
    end

    it 'carries the exemption the sale was filed with' do
      exemption = Spree::TaxExemption.new(reason_code: 'RESALE', certificate_number: 'C-100')

      line = present(exemptions: [exemption]).call[:lines].sole

      expect(line[:entityUseCode]).to eq('G')
      expect(line[:exemptionCode]).to eq('C-100')
    end

    # The amount comes from pre_tax_amount, so it is net. Flagging it inclusive
    # would have Avalara back tax out of a figure that never contained any,
    # crediting roughly 1/(1+rate) of the VAT actually charged.
    it 'states the credit as net of tax' do
      expect(present.call[:lines].sole[:taxIncluded]).to be(false)
    end

    # On an exclusive market the claim above holds either way, so it proves
    # nothing on its own — this is the market where the mistake shows, and the
    # one the legacy extension shipped it on: it sent the same net figure with
    # the sale document's inclusive flag, crediting a fraction of the VAT.
    it 'states the credit as net even where prices are sold gross' do
      market = create(:market, store: @default_store, tax_inclusive: true, currency: 'PLN')
      market.update!(country_codes: ['PL'])
      address = create(:address, country_code: 'PL', state_code: nil, city: 'Warszawa', zipcode: '00-526')
      order.update!(market: market, ship_address: address, bill_address: address)

      expect(SpreeAvalara.tax_inclusive?(order.reload)).to be(true)
      expect(present.call[:lines].sole[:taxIncluded]).to be(false)
      expect(present.call[:lines].sole[:amount]).to eq(-200)
    end
  end

  # Every unit of every line came back, so the whole pre-tax worth is credited.
  it 'credits a full return in full' do
    everything = [return_item(received: 4)]

    presenter = present(return_items: everything)

    expect(presenter.lines_worth).to eq(400)
    expect(presenter.call[:lines].sole).to include(quantity: 4, amount: -400)
  end

  # Worth is summed across lines and the scale applies to each, so a fault that
  # credited only the first line — or scaled each against its own worth — would
  # never show up in a single-line example.
  describe 'a return spanning several lines' do
    let(:second_line) { create(:line_item, order: order, cart: nil, price: 50, quantity: 2) }
    let(:both_lines) do
      [return_item(received: 4),
       instance_double(Spree::ReturnLineItem, line_item: second_line, received_quantity: 2,
                                              return: instance_double(Spree::Return, number: 'RET1'))]
    end

    before { second_line.update_column(:pre_tax_amount, 100) }

    it 'credits each line its own worth' do
      presenter = present(return_items: both_lines)

      expect(presenter.lines_worth).to eq(500)
      expect(presenter.call[:lines].map { |line| line[:amount] }).to eq([-400, -100])
    end

    it 'spreads a short refund across every line rather than exhausting the first' do
      presenter = present(return_items: both_lines, amount: 250)

      expect(presenter.scale).to eq(0.5)
      expect(presenter.call[:lines].map { |line| line[:amount] }).to eq([-200, -50])
      expect(presenter.call[:lines].sum { |line| line[:amount] }).to eq(-250)
    end
  end

  describe 'when the refund is short of the returned lines' do
    # An admin keeping a restocking fee refunded less than came back, and no more
    # tax may be credited than the refund actually carried.
    it 'credits every line proportionally' do
      expect(present(amount: 100).scale).to eq(0.5)
      expect(present(amount: 100).call[:lines].sole[:amount]).to eq(-100)
    end

    it 'never credits more than the lines are worth' do
      expect(present(amount: 5_000).scale).to eq(1)
      expect(present(amount: 5_000).call[:lines].sole[:amount]).to eq(-200)
    end

    it 'credits the full worth when no amount is named' do
      expect(present.scale).to eq(1)
    end
  end

  describe 'nothing to credit' do
    it 'is true when no units came back' do
      expect(present(return_items: [return_item(received: 0)])).to be_nothing_to_credit
    end

    it 'is true when the return is empty' do
      expect(present(return_items: [])).to be_nothing_to_credit
    end

    it 'is false for a real return' do
      expect(present).not_to be_nothing_to_credit
    end
  end
end
