require 'spec_helper'

RSpec.describe Spree::Sellers::PanelUrl do
  let(:store) { @default_store }

  after do
    Spree::Config[:seller_panel_url] = nil
    Spree::Config[:dashboard_url] = nil
  end

  it 'prefers an explicitly configured panel origin' do
    Spree::Config[:seller_panel_url] = 'https://sellers.example.com/'
    Spree::Config[:dashboard_url] = 'https://admin.example.com'

    expect(described_class.call(store: store)).to eq('https://sellers.example.com')
  end

  # The single-node topology: Spree serves the panel itself at /sellers, so a
  # link there works without any hostname of its own. `Spree::SellerPanel`
  # ships in the optional spree_dashboard gem, which core's suite does not
  # load — hence the resolver's `defined?` guard, and this stand-in.
  context 'when this app serves a seller panel bundle' do
    before do
      stub_const('Spree::SellerPanel', Module.new do
        def self.dist_path = '/tmp/panel-dist'
      end)
    end

    it 'points at the mount rather than the dashboard' do
      Spree::Config[:dashboard_url] = 'https://admin.example.com'

      expect(described_class.call(store: store)).to end_with('/sellers')
    end
  end

  # A marketplace that has not deployed a panel still has to send a working
  # invitation, and the dashboard at least exists.
  it 'falls back to the dashboard origin when nothing else resolves' do
    Spree::Config[:dashboard_url] = 'https://admin.example.com'

    expect(described_class.call(store: store)).to eq('https://admin.example.com')
  end
end
