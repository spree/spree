require 'spec_helper'

RSpec.describe Spree::Core::Partials do
  let(:environment) do
    Struct.new(
      :product_form_partials,
      :dashboard_analytics_partials,
      :order_page_sidebar_partials,
      :admin_users_actions_partials,
      :navigation # Not a _partials attribute
    )
  end
  let(:config) { environment.new }
  let(:partials) { described_class.new(config, environment) }

  describe '#initialize' do
    it 'accepts config and environment parameters' do
      expect { described_class.new(config, environment) }.not_to raise_error
    end

    it 'sets config and environment' do
      expect(partials.config).to eq(config)
      expect(partials.environment).to eq(environment)
    end
  end

  describe '#partial_members' do
    it 'returns only members ending with _partials' do
      members = partials.partial_members
      expect(members).to include(:product_form_partials)
      expect(members).to include(:dashboard_analytics_partials)
      expect(members).to include(:order_page_sidebar_partials)
      expect(members).to include(:admin_users_actions_partials)
      expect(members).not_to include(:navigation)
    end
  end

  describe '#keys' do
    it 'returns partial member names without _partials suffix' do
      keys = partials.keys
      expect(keys).to include('product_form')
      expect(keys).to include('dashboard_analytics')
      expect(keys).to include('order_page_sidebar')
      expect(keys).to include('admin_users_actions')
      expect(keys).not_to include('navigation')
    end
  end

  describe 'dynamically defined methods' do
    it 'defines getter methods for all _partials attributes' do
      expect(partials).to respond_to(:product_form)
      expect(partials).to respond_to(:order_page_sidebar)
      expect(partials).to respond_to(:dashboard_analytics)
      expect(partials).to respond_to(:admin_users_actions)
    end

    it 'defines setter methods for all _partials attributes' do
      expect(partials).to respond_to(:product_form=)
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
    it 'calls the config with the full _partials attribute name' do
      config.product_form_partials = ['partial1', 'partial2']

      result = partials.product_form

      expect(result).to eq(['partial1', 'partial2'])
    end

    it 'works with different partial types' do
      config.dashboard_analytics_partials = ['analytics']
      config.order_page_sidebar_partials = ['sidebar']

      expect(partials.dashboard_analytics).to eq(['analytics'])
      expect(partials.order_page_sidebar).to eq(['sidebar'])
    end
  end

  describe 'setter methods' do
    it 'sets the config with the full _partials attribute name' do
      partials.product_form = ['custom_partial']

      expect(config.product_form_partials).to eq(['custom_partial'])
    end

    it 'works with different partial types' do
      partials.dashboard_analytics = ['new_analytics']
      partials.order_page_sidebar = ['new_sidebar']

      expect(config.dashboard_analytics_partials).to eq(['new_analytics'])
      expect(config.order_page_sidebar_partials).to eq(['new_sidebar'])
    end
  end
end
