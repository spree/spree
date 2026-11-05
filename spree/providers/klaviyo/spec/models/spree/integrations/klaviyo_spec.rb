require 'spec_helper'

RSpec.describe Spree::Integrations::Klaviyo do
  let(:store) { @default_store }

  let(:switches) do
    %w[sends_order_confirmation sends_order_cancellation sends_shipping_confirmation sends_refund_confirmation
       use_database_ids_as_external_ids]
  end

  describe 'registration' do
    it 'is a registered integration' do
      expect(Spree.integrations).to include('Spree::Integrations::Klaviyo')
    end

    it 'answers klaviyo as its wire type' do
      expect(described_class.api_type).to eq('klaviyo')
    end

    it 'appears in the gallery in the marketing group with its credentials and switches' do
      entry = Spree::Integration.discovery_entries.find { |candidate| candidate[:type] == 'klaviyo' }
      properties = entry[:schema].with_indifferent_access[:properties].keys

      expect(entry[:group]).to eq('marketing')
      expect(entry[:logo_url]).to eq('https://spreecommerce.org/docs/images/integrations/logos/klaviyo.png')
      expect(entry[:docs_url]).to eq('https://spreecommerce.org/docs/integrations/marketing/klaviyo')
      expect(entry[:description]).to be_present
      expect(properties).to match_array(%w[klaviyo_private_api_key default_newsletter_list_id] + switches)
      expect(properties).not_to include('klaviyo_public_api_key')
    end
  end

  describe 'the private key' do
    it 'is stored in secret_preferences, never in preferences' do
      integration = create(:klaviyo_integration, store: store, preferred_klaviyo_private_api_key: 'pk_secret')

      expect(integration.reload.preferred_klaviyo_private_api_key).to eq('pk_secret')
      expect(integration.preferences).not_to have_key(:klaviyo_private_api_key)
      expect(integration.secret_preferences).to include(klaviyo_private_api_key: 'pk_secret')
    end
  end

  describe 'a row left by the 1.x gem' do
    def insert_row(preferences:, secret_preferences: nil)
      id = Spree::Integration.insert_all!(
        [{ type: 'Spree::Integrations::Klaviyo', store_id: store.id, active: true,
           preferences: preferences, secret_preferences: secret_preferences,
           created_at: Time.current, updated_at: Time.current }],
        returning: :id
      ).rows.first.first

      Spree::Integration.find(id)
    end

    it 'loads and reads its key and list id, ignoring the public key' do
      integration = insert_row(
        preferences: { default_newsletter_list_id: 'LIST01', klaviyo_public_api_key: 'AbC123' },
        secret_preferences: { klaviyo_private_api_key: 'pk_old' }
      )

      expect(integration).to be_a(described_class)
      expect(integration.preferred_klaviyo_private_api_key).to eq('pk_old')
      expect(integration.preferred_default_newsletter_list_id).to eq('LIST01')
    end

    it 'reads a key still in the plain preferences column' do
      integration = insert_row(
        preferences: { klaviyo_private_api_key: 'pk_plain', default_newsletter_list_id: 'LIST01' }
      )

      expect(integration.preferred_klaviyo_private_api_key).to eq('pk_plain')
      expect(integration.preferred_default_newsletter_list_id).to eq('LIST01')
    end
  end

  describe '#replaced_customer_emails' do
    let(:integration) { build(:klaviyo_integration, store: store) }

    let(:switch_emails) do
      {
        sends_order_confirmation: %w[spree/order_mailer/confirm_email spree/order_group_mailer/confirm_email],
        sends_order_cancellation: %w[spree/order_mailer/cancel_email],
        sends_shipping_confirmation: %w[spree/fulfillment_mailer/fulfilled_email],
        sends_refund_confirmation: %w[spree/return_mailer/refunded_email]
      }
    end

    let(:token_emails) do
      %w[spree/customer_mailer/password_reset_email spree/customer_mailer/data_export_email
         spree/customer_mailer/data_request_confirmation_email spree/digital_asset_mailer/files_ready_email
         spree/order_mailer/payment_link_email spree/company_mailer/invitation_email]
    end

    it 'is only the newsletter confirmation with every switch off' do
      expect(integration.replaced_customer_emails).to eq(['spree/newsletter_mailer/email_confirmation'])
    end

    it 'adds exactly the emails of each switch that is on' do
      switch_emails.each do |switch, emails|
        integration = build(:klaviyo_integration, store: store, "preferred_#{switch}": true)

        expect(integration.replaced_customer_emails).to match_array(['spree/newsletter_mailer/email_confirmation'] + emails)
      end
    end

    it 'never lists an email carrying a token, with every switch on' do
      switch_emails.each_key { |switch| integration.public_send(:"preferred_#{switch}=", true) }

      expect(integration.replaced_customer_emails & token_emails).to be_empty
    end
  end

  describe 'the store asking whether to send a customer email' do
    let!(:integration) do
      create(:klaviyo_integration, :active, store: store, preferred_sends_order_confirmation: confirmation)
    end

    context 'with order confirmation on' do
      let(:confirmation) { true }

      it 'leaves the order confirmation to Klaviyo' do
        expect(store.sends_customer_email?('spree/order_mailer/confirm_email')).to be(false)
      end
    end

    context 'with order confirmation off' do
      let(:confirmation) { false }

      it 'sends the order confirmation itself' do
        expect(store.sends_customer_email?('spree/order_mailer/confirm_email')).to be(true)
      end
    end
  end
end
