require 'spec_helper'
require Spree::Core::Engine.root.join('lib/spree/core/previews/api_key_preview')

describe Spree::ApiKeyPreview do
  it 'renders the new API key email without creating a key' do
    expect {
      message = described_class.new({}).secret_key_created

      expect(message.subject).to include('New Admin API key')
      expect(email_body(message)).to include('Warehouse integration', '203.0.113.42')
    }.not_to change(Spree::ApiKey, :count)
  end
end
