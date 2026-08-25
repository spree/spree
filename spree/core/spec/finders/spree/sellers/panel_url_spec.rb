require 'spec_helper'

RSpec.describe Spree::Sellers::PanelUrl do
  let(:store) { @default_store }

  # Captured and put back rather than reset to nil: a suite that configured
  # either of these would silently lose it for every example after this file.
  around do |example|
    panel = Spree::Config[:seller_panel_url]
    dashboard = Spree::Config[:dashboard_url]
    example.run
  ensure
    Spree::Config[:seller_panel_url] = panel
    Spree::Config[:dashboard_url] = dashboard
  end

  it 'prefers an explicitly configured panel origin' do
    Spree::Config[:seller_panel_url] = 'https://sellers.example.com/'
    Spree::Config[:dashboard_url] = 'https://admin.example.com'

    expect(described_class.call(store: store)).to eq('https://sellers.example.com')
  end

  # The single-node topology: Spree serves the panel itself at /sellers, so a
  # link there works without any hostname of its own. `Spree::Dashboard`
  # ships in the optional spree_dashboard gem, which core's suite does not
  # load — hence the resolver's `defined?` guard, and this stand-in.
  context 'when this app serves a seller panel bundle' do
    before do
      stub_const('Spree::Dashboard', Module.new do
        def self.seller_panel_dist_path = '/tmp/panel-dist'
      end)
    end

    it 'points at the mount rather than the dashboard' do
      Spree::Config[:dashboard_url] = 'https://admin.example.com'

      expect(described_class.call(store: store)).to end_with('/sellers')
    end
  end

  # A marketplace that has not deployed a panel still has to send a working
  # invitation, and the dashboard at least exists — but a seller who accepts
  # there gets an admin session, so the fallback says so out loud.
  it 'falls back to the dashboard origin when nothing else resolves' do
    Spree::Config[:dashboard_url] = 'https://admin.example.com'

    expect(described_class.call(store: store)).to eq('https://admin.example.com')
  end

  it 'warns when it falls back, since the session audience will be wrong' do
    Spree::Config[:dashboard_url] = 'https://admin.example.com'
    expect(Rails.logger).to receive(:warn).with(/No seller panel is configured/)

    described_class.call(store: store)
  end

  it 'does not warn when a panel origin is configured' do
    Spree::Config[:seller_panel_url] = 'https://sellers.example.com'
    expect(Rails.logger).not_to receive(:warn).with(/No seller panel is configured/)

    described_class.call(store: store)
  end
end
