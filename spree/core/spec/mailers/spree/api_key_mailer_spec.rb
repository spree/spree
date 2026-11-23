require 'spec_helper'

describe Spree::ApiKeyMailer, type: :mailer do
  let(:store) { @default_store }
  let(:creator) { create(:admin_user, first_name: 'Damian', last_name: 'Smith') }
  let(:admin_user) { create(:admin_user, email: 'owner@example.com', first_name: 'Alex') }
  let(:api_key) { create(:api_key, :secret, store: store, name: 'Mac Mini', scopes: %w[read_orders], created_by: creator) }

  describe '#secret_key_created' do
    let(:message) { described_class.secret_key_created(api_key, admin_user, ip_address: '203.0.113.7') }

    it 'sends to the admin with the store in the subject' do
      expect(message.to).to eq(['owner@example.com'])
      expect(message.subject).to eq("New Admin API key created in #{store.name}")
    end

    it 'names the key, its creator, its scopes and where the request came from' do
      body = email_body(message)

      expect(body).to include('Hi Alex,')
      expect(body).to include('Damian Smith created a new Admin API key named &quot;Mac Mini&quot;')
      expect(body).to include("#{api_key.token_prefix}…")
      expect(body).to include('read_orders')
      expect(body).to include('203.0.113.7')
    end

    it 'never carries the secret token' do
      expect(email_body(message)).not_to include(api_key.plaintext_token)
    end

    it "links to the store's API keys in the dashboard" do
      allow(Spree::Stores::DashboardUrl).to receive(:call).with(store: store).and_return('https://admin.example.com')

      expect(email_body(message)).to include("https://admin.example.com/#{store.prefixed_id}/settings/api-keys")
    end

    it "shows the creation time in the store's time zone" do
      la_store = create(:store, preferred_timezone: 'America/Los_Angeles')
      key = create(:api_key, :secret, store: la_store, name: 'LA key', created_at: Time.utc(2026, 11, 23, 1, 30))

      expect(email_body(described_class.secret_key_created(key, admin_user))).to include('2026-11-22 17:30 PST')
    end

    it 'still reads well without a creator or an IP address' do
      api_key.update_columns(created_by_id: nil, created_by_type: nil)

      body = email_body(described_class.secret_key_created(api_key.reload, admin_user))

      expect(body).to include('A new Admin API key named &quot;Mac Mini&quot; was created')
      expect(body).not_to include('IP address')
    end
  end
end
