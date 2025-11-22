require 'spec_helper'

RSpec.describe 'Spree::Admin.partials' do
  describe 'integration with Spree::Admin module' do
    it 'provides access via Spree::Admin.partials' do
      expect(Spree::Admin).to respond_to(:partials)
      expect(Spree::Admin.partials).to be_a(Spree::Core::Partials)
    end

    it 'returns the same instance on multiple calls (memoized)' do
      first_call = Spree::Admin.partials
      second_call = Spree::Admin.partials

      expect(first_call).to be(second_call)
    end

    it 'uses the admin config and environment' do
      partials = Spree::Admin.partials
      expect(partials.config).to eq(Rails.application.config.spree_admin)
      expect(partials.environment).to eq(Spree::Admin::Engine::Environment)
    end
  end

  describe 'admin partial accessors' do
    let(:partials) { Spree::Admin.partials }

    it 'defines getter methods for admin _partials attributes' do
      # Test a sample of the many admin partial attributes
      expect(partials).to respond_to(:product_form)
      expect(partials).to respond_to(:product_form_sidebar)
      expect(partials).to respond_to(:order_page_sidebar)
      expect(partials).to respond_to(:dashboard_analytics)
      expect(partials).to respond_to(:admin_users_actions)
    end

    it 'defines setter methods for admin _partials attributes' do
      expect(partials).to respond_to(:product_form=)
      expect(partials).to respond_to(:product_form_sidebar=)
      expect(partials).to respond_to(:order_page_sidebar=)
      expect(partials).to respond_to(:dashboard_analytics=)
      expect(partials).to respond_to(:admin_users_actions=)
    end

    it 'does not define methods for non-partials attributes' do
      # :navigation is in Environment but doesn't end with _partials
      expect(partials).not_to respond_to(:navigation)
    end
  end

  describe 'getter methods' do
    let(:partials) { Spree::Admin.partials }

    it 'returns the config values' do
      allow(Rails.application.config.spree_admin).to receive(:product_form_partials).and_return(['form_widget'])
      expect(partials.product_form).to eq(['form_widget'])
    end

    it 'works with different partial types' do
      allow(Rails.application.config.spree_admin).to receive(:dashboard_analytics_partials).and_return(['analytics'])
      allow(Rails.application.config.spree_admin).to receive(:order_page_sidebar_partials).and_return(['sidebar'])

      expect(partials.dashboard_analytics).to eq(['analytics'])
      expect(partials.order_page_sidebar).to eq(['sidebar'])
    end
  end

  describe 'setter methods' do
    let(:partials) { Spree::Admin.partials }

    after do
      Rails.application.config.spree_admin.product_form_partials = []
      Rails.application.config.spree_admin.dashboard_analytics_partials = []
      Rails.application.config.spree_admin.order_page_sidebar_partials = []
    end

    it 'sets the config values' do
      partials.product_form = ['custom_form']
      expect(Rails.application.config.spree_admin.product_form_partials).to eq(['custom_form'])
    end

    it 'works with different partial types' do
      partials.dashboard_analytics = ['custom_analytics']
      partials.order_page_sidebar = ['custom_sidebar']

      expect(Rails.application.config.spree_admin.dashboard_analytics_partials).to eq(['custom_analytics'])
      expect(Rails.application.config.spree_admin.order_page_sidebar_partials).to eq(['custom_sidebar'])
    end
  end

  describe '#keys' do
    let(:partials) { Spree::Admin.partials }

    it 'returns all available partial keys' do
      keys = partials.keys
      # Test a sample of the many admin partial keys
      expect(keys).to include('product_form')
      expect(keys).to include('product_form_sidebar')
      expect(keys).to include('order_page_sidebar')
      expect(keys).to include('dashboard_analytics')
      expect(keys).to include('admin_users_actions')

      # Should not include non-partials attributes
      expect(keys).not_to include('navigation')
    end

    it 'returns all admin partial keys' do
      keys = partials.keys
      # Admin has many _partials attributes (all Environment members except navigation)
      partials_count = Spree::Admin::Engine::Environment.members.count { |m| m.to_s.end_with?('_partials') }
      expect(keys.length).to eq(partials_count)
      expect(keys.length).to be > 100 # Sanity check
    end
  end
end
