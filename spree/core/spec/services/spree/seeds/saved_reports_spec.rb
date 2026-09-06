require 'spec_helper'

RSpec.describe Spree::Seeds::SavedReports do
  let(:store) { @default_store }

  it 'seeds the classic report set once per store' do
    expect { described_class.call }.to change { store.saved_reports.seeded.count }
      .from(0).to(described_class::REPORTS.size)

    expect { described_class.call }.not_to change { store.saved_reports.count }
    expect(store.saved_reports.find_by(name: 'Top products').reporting_query.dimensions.first[:dimension].name).to eq(:product)
  end

  it 'treats a merchant report differing only in case as already present' do
    create(:saved_report, store: store, name: 'top products')

    expect { described_class.call }.not_to raise_error
    expect(store.saved_reports.where('LOWER(name) = ?', 'top products').count).to eq(1)
  end
end
