# frozen_string_literal: true

require 'spec_helper'

describe Spree::Api::Configuration do
  describe '#webhooks_allowed_internal_hosts' do
    it 'allows no internal hosts by default' do
      stub_const('ENV', ENV.to_h.except('SPREE_WEBHOOKS_ALLOWED_INTERNAL_HOSTS'))

      expect(described_class.new.webhooks_allowed_internal_hosts).to eq([])
    end

    it 'reads a comma-separated list from the environment' do
      stub_const('ENV', ENV.to_h.merge('SPREE_WEBHOOKS_ALLOWED_INTERNAL_HOSTS' => 'storefront.internal, .svc.cluster.local'))

      expect(described_class.new.webhooks_allowed_internal_hosts).to eq(['storefront.internal', '.svc.cluster.local'])
    end
  end
end
