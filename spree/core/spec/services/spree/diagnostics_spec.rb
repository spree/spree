require 'spec_helper'

RSpec.describe Spree::Diagnostics do
  let(:store) { @default_store }
  let!(:market) { create(:market, store: store, name: 'Secret Market Name', currency: 'EUR', countries: [create(:country, iso: 'DE')]) }

  before do
    store.update_columns(name: 'Secret Store Name', mail_from_address: 'owner@secret-shop.example')
    create(:channel, store: store, name: 'Secret Channel Name')
  end

  subject(:report) { described_class.report(store: store) }

  def section(key)
    report.sections.find { |section| section[:key] == key }
  end

  def value(key, label)
    section(key)[:rows].find { |row| row[:label] == label }&.dig(:value)
  end

  it 'describes the installation' do
    expect(value('platform', 'Version')).to eq(Spree.version)
    expect(value('platform', 'Gems')).to include("spree_core #{Spree.version}")
    expect(value('runtime', 'Ruby')).to start_with(RUBY_VERSION)
    expect(value('infrastructure', 'Database')).to start_with('postgresql').or start_with('mysql').or start_with('sqlite')
  end

  it 'never includes names, emails or URLs' do
    markdown = report.to_markdown

    expect(markdown).not_to include('Secret Store Name', 'Secret Market Name', 'Secret Channel Name', 'secret-shop.example')
    expect(report.to_h.to_json).not_to include('Secret')
  end

  it 'reports changed flags, never free-form strings' do
    store.update!(preferred_guest_checkout: !store.preferred_guest_checkout)
    store.update_columns(storefront_custom_code_head: '<script>secret</script>')

    labels = section('preferences')[:rows].pluck(:label)
    expect(labels).to include('store.guest_checkout')
    expect(labels).not_to include('store.storefront_url')
    expect(report.to_markdown).not_to include('secret</script>')
  end

  it 'reports changed fixed-choice settings' do
    store.update!(preferred_unit_system: store.preferred_unit_system == 'metric' ? 'imperial' : 'metric')

    expect(value('preferences', 'store.unit_system')).to eq(store.preferred_unit_system)
  end

  it 'counts extensions built on Spree without naming them' do
    expect(value('platform', 'Other gems built on Spree')).to match(/\A\d+\z/)
  end

  it 'keeps going when a row fails to read' do
    allow(Etc).to receive(:uname).and_raise(Errno::EACCES)

    expect(value('runtime', 'Operating system')).to eq('unavailable')
    expect(value('runtime', 'Ruby')).to start_with(RUBY_VERSION)
  end

  it 'reports a broken section instead of failing' do
    allow(Spree).to receive(:diagnostics_sections).and_return(['Spree::Diagnostics::Sections::Runtime', 'Missing::Section'])

    expect(report.sections.pluck(:key)).to eq(%w[runtime section])
  end

  it 'adds what only the caller can see' do
    report = described_class.report(store: store, extra_sections: [{ title: 'CLI', rows: { 'Node' => 'v24.1.0' } }])

    expect(report.sections.last).to eq(key: 'cli', title: 'CLI', rows: [{ label: 'Node', value: 'v24.1.0' }])
    expect(report.to_markdown).to include("**CLI**\n\n| | |\n| --- | --- |\n| Node | v24.1.0 |")
  end

  it 'links to a pre-filled issue, or the empty form when the report is too long' do
    expect(report.issue_url).to start_with("#{described_class::ISSUE_URL}&environment=%3Cdetails%3E")
    expect(report.issue_prefilled?).to be(true)

    stub_const("#{described_class}::MAX_ISSUE_URL_LENGTH", 100)
    long = described_class.report(store: store)
    expect(long.issue_url).to eq(described_class::ISSUE_URL)
    expect(long.issue_prefilled?).to be(false)
  end

  it 'leaves recent errors out when asked' do
    report = described_class.report(store: store, errors: false)

    expect(report.errors).to be_nil
    expect(report.to_markdown).not_to include('Recent errors')
  end

  it 'renders Markdown that folds into a details block' do
    expect(report.to_markdown).to start_with('<details>').and end_with('</details>')
    expect(report.to_markdown).to include("**Runtime**\n\n| | |\n| --- | --- |\n| Ruby | #{RUBY_VERSION}")
  end
end
