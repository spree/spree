require 'spec_helper'

RSpec.describe SpreeAvalara::RefundPresenter do
  let(:integration) { build(:avalara_integration, store: @default_store, preferred_company_code: 'SPARK') }
  let(:order) { create(:order, store: @default_store, completed_at: Time.utc(2026, 5, 1, 12, 0, 0)) }
  let(:line_item) { create(:line_item, order: order, cart: nil, price: 100, quantity: 4) }

  # Two units of a 100 line, with 8.00 of tax added on top given back.
  def credited_line(line: line_item, quantity: 2, worth: 216, tax: 16)
    instance_double(Spree::ReturnLineItem, line_item: line, credited_quantity: quantity,
                                           credited_worth: worth.to_d, credited_tax_total: tax.to_d)
  end

  def present(**overrides)
    described_class.new(**{ order: order, integration: integration, return_items: [credited_line] }.merge(overrides))
  end

  before { allow(SpreeAvalara).to receive(:post_sale_record).and_return(instance_double(Spree::Return, number: 'RET1')) }

  it 'credits the units at what went back before tax, with the tax core gave back' do
    expect(present.call[:lines].sole).to include(
      number: line_item.prefixed_id, quantity: 2, amount: -200, taxIncluded: false,
      taxOverride: { type: 'TaxAmount', reason: 'Refund', taxAmount: -16, taxDate: '2026-05-01' }
    )
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

  # A replayed refund must adjust this document, not file a second credit.
  it 'keys the document to the order and the return, claim or exchange' do
    expect(present.code).to eq("#{order.number}-RET1")
  end

  # The credit belongs to the period the money went back in, while its tax
  # follows the sale it reverses.
  it 'dates the credit on the refund day and taxes it as of the original supply' do
    Timecop.freeze(Time.utc(2026, 7, 3, 12, 0, 0)) do
      payload = present.call

      expect(payload[:date]).to eq('2026-07-03')
      expect(payload[:taxOverride]).to eq(type: 'TaxDate', reason: 'Refund', taxDate: '2026-05-01')
    end
  end

  # The credit has to be classified the way the sale was, or Avalara files it
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

    # A sale that carried its tax inside the price gives back gross money, and
    # only the part of it that is not tax is the credited amount.
    it 'takes the tax out of money refunded gross' do
      gross = credited_line(quantity: 1, worth: 100, tax: 18.70)

      expect(present(return_items: [gross]).call[:lines].sole).to include(
        amount: -81.30, taxOverride: hash_including(taxAmount: -18.70)
      )
    end

    # An exempt sale gave nothing back in tax, and its credit says so rather
    # than letting Avalara price the return.
    it 'credits zero tax where the sale charged none' do
      exempt = credited_line(worth: 200, tax: 0)

      expect(present(return_items: [exempt]).call[:lines].sole).to include(
        amount: -200, taxOverride: hash_including(taxAmount: 0)
      )
    end
  end

  # A restocking fee or a part refund: the money is divided across the lines
  # as core divided it before writing their credit rows.
  describe 'a refund short of the lines' do
    let(:second_line) { create(:line_item, order: order, cart: nil, price: 50, quantity: 2) }
    let(:both_lines) do
      [credited_line(worth: 216, tax: 8), credited_line(line: second_line, quantity: 2, worth: 108, tax: 4)]
    end

    it 'divides the money in proportion to what each line is worth' do
      lines = present(return_items: both_lines, amount: 162).call[:lines]

      expect(lines.map { |line| line[:amount] }).to eq([-100, -50])
      expect(lines.map { |line| line.dig(:taxOverride, :taxAmount) }).to eq([-8, -4])
    end

    # Core divides a claim's refund by what was agreed per line, not by worth.
    it 'divides a claim by the refund agreed per line' do
      claim_lines = [[line_item, 107.25], [second_line, 0]].map do |line, agreed|
        instance_double(Spree::ClaimLineItem, line_item: line, credited_quantity: 1, credited_worth: 107.25.to_d,
                                              credited_tax_total: agreed.positive? ? 7.25.to_d : 0.to_d,
                                              refund_amount: agreed.to_d)
      end

      lines = present(return_items: claim_lines, amount: 107.25).call[:lines]

      expect(lines.sole).to include(amount: -100, taxOverride: hash_including(taxAmount: -7.25))
    end

    it 'credits each line its whole worth when the refund covers it' do
      lines = present(return_items: both_lines, amount: 5_000).call[:lines]

      expect(lines.map { |line| line[:amount] }).to eq([-208, -104])
    end

    # Rounding each line on its own would credit a cent nobody refunded.
    it 'lands the division on the cent' do
      pennies = create_list(:line_item, 2, order: order, cart: nil, price: 1, quantity: 1).map do |line|
        credited_line(line: line, quantity: 1, worth: 1, tax: 0)
      end

      lines = present(return_items: pennies, amount: 1.03).call[:lines]

      expect(lines.sum { |line| line[:amount] }).to eq(-1.03)
    end
  end

  describe 'the buyer registration' do
    let(:registration) { instance_double(Spree::TaxIdentifier, value: 'DE123456789') }

    # Dropping it re-prices the credit as a consumer refund, declaring VAT the
    # zero-rated sale never collected.
    it 'files the credit under the registration the sale was filed under' do
      expect(present(tax_identifier: registration).call[:businessIdentificationNo]).to eq('DE123456789')
    end

    it 'says nothing where the sale carried no registration' do
      expect(present.call).not_to have_key(:businessIdentificationNo)
    end
  end

  describe 'nothing to credit' do
    it 'is true when nothing went back' do
      expect(present(return_items: [credited_line(quantity: 0, worth: 0, tax: 0)])).to be_nothing_to_credit
      expect(present(amount: 0)).to be_nothing_to_credit
    end

    it 'is true when the return is empty' do
      expect(present(return_items: [])).to be_nothing_to_credit
    end

    it 'is false for a real refund' do
      expect(present).not_to be_nothing_to_credit
    end
  end
end
