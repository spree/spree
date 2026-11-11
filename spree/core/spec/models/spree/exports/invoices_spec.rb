require 'spec_helper'

RSpec.describe Spree::Exports::Invoices, type: :model do
  let(:store) { @default_store }
  let(:user) { create(:admin_user) }
  let(:order) { create(:completed_order_with_totals, store: store) }
  let!(:invoice) { create(:invoice, order: order, number: 'FV/2026/11/42', total: 123, net_total: 100, tax_total: 23) }
  let!(:credit_note) do
    create(:invoice, :credit_note, order: order, original_invoice: invoice, number: 'CN/1', total: -10, net_total: -8.13, tax_total: -1.87)
  end

  def export_rows(search_params: nil)
    export = described_class.new(store: store, user: user, search_params: search_params, record_selection: search_params ? 'filtered' : 'all')
    export.save!
    export.generate
    CSV.parse(export.attachment.download, headers: true)
  end

  it 'writes one row per invoice, with the original a credit note corrects' do
    rows = export_rows

    expect(rows.headers).to eq(Spree::CSV::InvoicePresenter::HEADERS)
    expect(rows.pluck('Number')).to contain_exactly('FV/2026/11/42', 'CN/1')
    expect(rows.find { |row| row['Number'] == 'CN/1' }.to_h).to include(
      'Kind' => 'credit_note', 'Corrects' => 'FV/2026/11/42', 'Order Number' => order.number,
      # The formula guard every export shares quotes a leading minus.
      'Total' => "'-10.00"
    )
  end

  it "writes times in the store's time zone" do
    allow(store).to receive(:preferred_timezone).and_return('Europe/Warsaw')
    invoice.update_columns(created_at: Time.utc(2026, 11, 2, 12, 0))

    row = Spree::CSV::InvoicePresenter.new(invoice, store).call

    expect(row[Spree::CSV::InvoicePresenter::HEADERS.index('Created At')]).to eq('2026-11-02 13:00:00')
  end

  it 'exports the filtered list' do
    expect(export_rows(search_params: { kind_eq: 'invoice' }.to_json).pluck('Number')).to eq(['FV/2026/11/42'])
  end

  it 'includes commission invoices only when its creator reads payouts, and says so' do
    create(:invoice, :commission, seller_payout: create(:seller_payout, store: store), number: 'COM/1')
    export = described_class.create!(store: store, user: user, record_selection: 'all')
    keyless = described_class.create!(store: store, record_selection: 'all')

    expect(export.additional_read_permission).to eq('read_payouts')
    expect(export.scope.pluck(:number)).to include('COM/1')
    expect(keyless.additional_read_permission).to be_nil
    expect(keyless.scope.pluck(:number)).not_to include('COM/1')
  end

  it "never includes another store's invoices" do
    create(:invoice, order: create(:completed_order_with_totals, store: create(:store)), number: 'OTHER-1')

    expect(export_rows.pluck('Number')).not_to include('OTHER-1')
  end
end
