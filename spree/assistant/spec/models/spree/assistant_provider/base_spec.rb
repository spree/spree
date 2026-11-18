require 'spec_helper'

RSpec.describe Spree::AssistantProvider::Base do
  describe '.to_api_hash' do
    it 'names the vendor and its integration by short name' do
      hash = Spree::AssistantProvider::Anthropic.to_api_hash(@default_store)

      expect(hash).to include(key: 'anthropic', integration_type: 'anthropic')
      expect(hash.values.grep(String)).to all(satisfy { |value| value.exclude?('::') })
    end
  end
end
