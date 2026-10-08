require 'spec_helper'

RSpec.describe Spree::AgentTools::AttachmentRegistry do
  subject(:registry) { described_class.new }

  describe 'what an extension can add' do
    it 'registers a file against the resource that owns it' do
      registry.register(resource: 'orders', attachment: :po_document, label: 'Purchase order')
      entry = registry.find('orders')

      expect(entry.attachment).to eq(:po_document)
      expect(entry.label).to eq('Purchase order')
    end

    it 'answers nothing for a resource nobody registered' do
      expect(registry.find('data_requests')).to be_nil
    end
  end

  describe 'what core ships' do
    # Named one at a time, because the question is never "is this a file?"
    # but "should a model be handed this one?"
    it 'does not offer a customer their own subject access export' do
      expect(Spree.agent_attachments.find('data_requests')).to be_nil
    end

    it 'does not offer the product a customer paid for' do
      expect(Spree.agent_attachments.find('digital_assets')).to be_nil
    end

    it 'offers the paperwork a merchant would otherwise open by hand' do
      expect(Spree.agent_attachments.map(&:resource)).to include('orders', 'shipping_labels')
    end
  end
end
