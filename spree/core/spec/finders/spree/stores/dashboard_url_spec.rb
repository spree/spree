require 'spec_helper'

RSpec.describe Spree::Stores::DashboardUrl do
  subject { described_class.call(store: store) }

  let(:store) { build(:store, url: 'shop.example.com') }

  context 'with the dashboard_url preference set' do
    before { Spree::Config.dashboard_url = 'https://admin.example.com/' }
    after { Spree::Config.dashboard_url = nil }

    it { is_expected.to eq('https://admin.example.com') }
  end

  context 'with SPREE_DASHBOARD_URL set' do
    before { stub_const('ENV', ENV.to_h.merge('SPREE_DASHBOARD_URL' => 'https://admin.worktree.localhost')) }

    it { is_expected.to eq('https://admin.worktree.localhost') }
  end

  context 'with only the deprecated admin_url set' do
    before { Spree::Config.admin_url = 'https://legacy.example.com' }
    after { Spree::Config.admin_url = nil }

    it { is_expected.to eq('https://legacy.example.com') }
  end

  context 'with nothing configured outside development' do
    before do
      stub_const('ENV', ENV.to_h.except('SPREE_DASHBOARD_URL'))
      allow(Rails.env).to receive(:development?).and_return(false)
    end

    it "falls back to the store's own URL, never a dev port" do
      expect(subject).to eq(store.formatted_url)
      expect(subject).not_to include('localhost:5173')
    end
  end

  # The bundled dashboard is a fact about the deployment, so it outranks the
  # Vite guess: an app serving /dashboard itself needs no second process for
  # the setup link to work.
  context 'when this app serves the bundled dashboard' do
    before do
      stub_const('ENV', ENV.to_h.except('SPREE_DASHBOARD_URL'))
      stub_const('Spree::Dashboard', Class.new { def self.dist_path = '/srv/dashboard' })
      allow(Rails.application.routes).to receive(:default_url_options).
        and_return(host: 'shop.example.com', protocol: 'https')
    end

    it 'points at the app’s own /dashboard mount, even in development' do
      allow(Rails.env).to receive(:development?).and_return(true)

      expect(subject).to eq('https://shop.example.com/dashboard')
    end

    it 'still yields to an explicitly configured origin' do
      Spree::Config.dashboard_url = 'https://admin.example.com'

      expect(subject).to eq('https://admin.example.com')
    ensure
      Spree::Config.dashboard_url = nil
    end

    it 'includes the port when the app runs on one' do
      allow(Rails.application.routes).to receive(:default_url_options).
        and_return(host: 'localhost', port: 3000)

      expect(subject).to eq('http://localhost:3000/dashboard')
    end
  end

  context 'when spree_dashboard is installed but has no build to serve' do
    before do
      stub_const('ENV', ENV.to_h.except('SPREE_DASHBOARD_URL'))
      stub_const('Spree::Dashboard', Class.new { def self.dist_path = nil })
      allow(Rails.env).to receive(:development?).and_return(true)
    end

    it 'skips the mount, which would 404, and uses the dev server' do
      expect(subject).to eq('http://localhost:5173')
    end
  end
end
