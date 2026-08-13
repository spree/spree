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
end
