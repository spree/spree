require 'spec_helper'

RSpec.describe Spree::Exports::Report, type: :model do
  let(:store) { @default_store }
  let(:admin) { create(:admin_user) }
  let(:query) { { 'metrics' => %w[gross_revenue orders_count], 'dimensions' => %w[channel] } }

  before { create(:completed_order_with_totals, store: store, completed_at: 3.days.ago) }

  it 'requires a user so members are authorized like the API' do
    export = described_class.new(store: store, search_params: { query: query })
    expect(export).not_to be_valid
    expect(export.errors[:user]).to be_present
  end

  it 'writes a dimensionless report as a single totals row' do
    export = described_class.create!(store: store, user: admin,
                                     search_params: { query: { 'metrics' => %w[gross_revenue orders_count] } })
    export.generate_csv

    rows = CSV.read(export.send(:export_tmp_file_path))
    expect(rows.first).to eq(['Total sales', 'Orders'])
    expect(rows.length).to eq(2)
    expect(rows.last.last.to_i).to eq(1)
  end

  it 'refuses at create a query that does not compile' do
    export = described_class.new(store: store, user: admin, search_params: { query: { 'metrics' => %w[nope] } })
    expect(export).not_to be_valid
    expect(export.errors[:search_params]).to be_present
  end

  it 'refuses at create a member the requesting user may not read' do
    viewer = create(:admin_user, :without_admin_role)
    create(:role_user, user: viewer, role: create(:role, permissions: %w[read_reports read_orders]))
    export = described_class.new(store: store, user: viewer,
                                 search_params: { query: { 'metrics' => %w[net_revenue], 'dimensions' => %w[product] } })

    expect(export).not_to be_valid
    expect(export.errors[:base]).to be_present
  end

  it 'gates on the reports scope and anchors on saved reports' do
    expect(described_class.required_scope).to eq(:reports)
    expect(described_class.model_class).to eq(Spree::SavedReport)
  end

  it 'writes labeled headers, one row per group, and a totals line' do
    export = described_class.create!(store: store, user: admin, search_params: { query: query })
    export.generate_csv

    rows = CSV.read(export.send(:export_tmp_file_path))
    expect(rows.first).to eq(['Sales channel', 'Total sales', 'Orders'])
    expect(rows.length).to eq(3) # header + one channel + total
    # Hydrated like the API: the channel's name, never its database id.
    expect(rows[1].first).to eq(Spree::Order.complete.last.channel.name)
    expect(rows.last.first).to eq('Total')
    expect(rows.last.last.to_i).to eq(1)
  end
end
