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
    # Read back by type and store, since MySQL's adapter has no `returning:`.
    def insert_row(preferences:, secret_preferences: nil)
      Spree::Integration.insert_all!(
        [{ type: 'Spree::Integrations::Klaviyo', store_id: store.id, active: true,
           preferences: preferences, secret_preferences: secret_preferences,
           created_at: Time.current, updated_at: Time.current }]
      )

      Spree::Integration.where(type: 'Spree::Integrations::Klaviyo', store_id: store.id).sole
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

  describe 'the Klaviyo client' do
    let(:integration) { build(:klaviyo_integration, store: store, preferred_klaviyo_private_api_key: 'pk_store_a') }
    let(:lists_api) { instance_double(KlaviyoAPI::ListsApi, get_list_with_http_info: [{}, 200, {}]) }
    let(:clients) { [] }

    before do
      allow(KlaviyoAPI::ListsApi).to receive(:new) do |client|
        clients << client
        lists_api
      end
    end

    it "sends each integration's own key" do
      other = build(:klaviyo_integration, store: create(:store), preferred_klaviyo_private_api_key: 'pk_store_b')

      integration.can_connect?
      other.can_connect?

      expect(clients.map { |client| client.config.api_key_with_prefix('Klaviyo-API-Key') }).
        to eq(['Klaviyo-API-Key pk_store_a', 'Klaviyo-API-Key pk_store_b'])
    end

    it 'never configures the SDK globally' do
      expect(KlaviyoAPI).not_to receive(:configure)

      integration.can_connect?
    end

    it 'times out after 10 seconds and never logs bodies' do
      integration.can_connect?

      expect(clients.first.config.timeout).to eq(10)
      expect(clients.first.config.debugging).to be(false)
    end
  end

  describe '#can_connect?' do
    it 'names a missing key without calling Klaviyo' do
      integration = build(:klaviyo_integration, store: store, preferred_klaviyo_private_api_key: '')

      expect(KlaviyoAPI::ListsApi).not_to receive(:new)
      expect(integration.can_connect?).to be(false)
      expect(integration.connection_error_message).to match(/private API key/)
    end

    it 'names a missing list id without calling Klaviyo' do
      integration = build(:klaviyo_integration, store: store, preferred_default_newsletter_list_id: '')

      expect(KlaviyoAPI::ListsApi).not_to receive(:new)
      expect(integration.can_connect?).to be(false)
      expect(integration.connection_error_message).to match(/list/)
    end

    it "refuses activation with Klaviyo's own detail" do
      integration = build(:klaviyo_integration, store: store, active: true)
      error = KlaviyoAPI::ApiError.new(code: 404, response_headers: {},
                                       response_body: { errors: [{ code: 'not_found', detail: 'A list with id LIST01 does not exist.' }] }.to_json)
      allow(KlaviyoAPI::ListsApi).to receive(:new).and_return(instance_double(KlaviyoAPI::ListsApi).tap do |api|
        allow(api).to receive(:get_list_with_http_info).and_raise(error)
      end)

      expect(integration).not_to be_valid
      expect(integration.errors[:base]).to eq(['A list with id LIST01 does not exist.'])
    end
  end

  describe 'API verbs' do
    let(:integration) { build(:klaviyo_integration, store: store, preferred_default_newsletter_list_id: 'LIST01') }
    let(:profiles_api) { instance_double(KlaviyoAPI::ProfilesApi) }
    let(:events_api) { instance_double(KlaviyoAPI::EventsApi) }
    let(:data_privacy_api) { instance_double(KlaviyoAPI::DataPrivacyApi) }

    before do
      allow(KlaviyoAPI::ProfilesApi).to receive(:new).and_return(profiles_api)
      allow(KlaviyoAPI::EventsApi).to receive(:new).and_return(events_api)
      allow(KlaviyoAPI::DataPrivacyApi).to receive(:new).and_return(data_privacy_api)
    end

    it 'imports a profile' do
      profile = SpreeKlaviyo::Profile.new(email: 'ada@example.com', external_id: 'cus_1')
      expect(profiles_api).to receive(:create_or_update_profile_with_http_info).with(profile.to_body).and_return([{}, 201, {}])

      integration.import_profile(profile)
    end

    it 'subscribes an address to the list with email-marketing consent' do
      expect(profiles_api).to receive(:bulk_subscribe_profiles_with_http_info) do |body|
        expect(body.dig(:data, :type)).to eq('profile-subscription-bulk-create-job')
        expect(body.dig(:data, :attributes, :profiles, :data, 0, :attributes)).
          to eq(email: 'ada@example.com', subscriptions: { email: { marketing: { consent: 'SUBSCRIBED' } } })
        expect(body.dig(:data, :relationships, :list, :data)).to eq(type: 'list', id: 'LIST01')
        [nil, 202, {}]
      end

      integration.subscribe('ada@example.com')
    end

    it 'unsubscribes an address, revoking its email-marketing consent' do
      expect(profiles_api).to receive(:bulk_unsubscribe_profiles_with_http_info) do |body|
        expect(body.dig(:data, :type)).to eq('profile-subscription-bulk-delete-job')
        expect(body.dig(:data, :attributes, :profiles, :data, 0, :attributes, :subscriptions, :email, :marketing, :consent)).
          to eq('UNSUBSCRIBED')
        [nil, 202, {}]
      end

      integration.unsubscribe('ada@example.com')
    end

    it 'creates an event' do
      event = SpreeKlaviyo::MetricEvent.new(metric: 'Placed Order', email: 'ada@example.com', unique_id: 'or_1', currency: 'USD')
      expect(events_api).to receive(:create_event_with_http_info).with(event.to_body).and_return([nil, 202, {}])

      integration.create_event(event)
    end

    it 'requests a profile deletion by email' do
      expect(data_privacy_api).to receive(:request_profile_deletion_with_http_info).with(
        { data: { type: 'data-privacy-deletion-job',
                  attributes: { profile: { data: { type: 'profile', attributes: { email: 'ada@example.com' } } } } } }
      ).and_return([nil, 202, {}])

      integration.request_profile_deletion('ada@example.com')
    end

    [[503, 'a 5xx'], [nil, 'a timeout'], [0, 'a failed connection']].each do |code, label|
      it "raises #{label} as a transient error, keeping its status" do
        allow(profiles_api).to receive(:bulk_subscribe_profiles_with_http_info).and_raise(KlaviyoAPI::ApiError.new(code: code))

        expect { integration.subscribe('ada@example.com') }.
          to raise_error(SpreeKlaviyo::TransientError) { |error| expect(error.code).to eq(code) }
      end
    end

    it "never carries Klaviyo's headers or body in a transient error's message" do
      error = KlaviyoAPI::ApiError.new(code: 503, response_headers: { 'X-Email' => 'ada@example.com' },
                                       response_body: '{"detail":"ada@example.com"}')
      allow(profiles_api).to receive(:bulk_subscribe_profiles_with_http_info).and_raise(error)

      expect { integration.subscribe('ada@example.com') }.to raise_error(SpreeKlaviyo::TransientError) do |transient|
        expect(transient.message).to eq('Klaviyo answered 503')
        expect(transient.response_body).to include('ada@example.com')
      end
    end

    it 'summarises a body that is JSON but not an object as having no errors' do
      ['null', '[]', '"oops"'].each do |body|
        error = KlaviyoAPI::ApiError.new(code: 502, response_headers: {}, response_body: body)

        expect(described_class.error_summaries(error)).to eq([])
        expect(described_class.error_details(error)).to eq([])
      end
    end

    it 'raises any other 4xx as the SDK raised it' do
      allow(profiles_api).to receive(:bulk_subscribe_profiles_with_http_info).and_raise(KlaviyoAPI::ApiError.new(code: 403))

      expect { integration.subscribe('ada@example.com') }.to raise_error(KlaviyoAPI::ApiError) do |error|
        expect(error).not_to be_a(SpreeKlaviyo::TransientError)
        expect(error.code).to eq(403)
      end
    end

    it "lets Klaviyo's error reach the caller" do
      allow(profiles_api).to receive(:bulk_subscribe_profiles_with_http_info).and_raise(KlaviyoAPI::ApiError.new(code: 503))

      expect { integration.subscribe('ada@example.com') }.to raise_error(KlaviyoAPI::ApiError) { |error| expect(error.code).to eq(503) }
    end

    it 'logs the method, path, status and duration, and no email or body' do
      lines = []
      allow(Rails.logger).to receive(:info) { |line| lines << line }
      allow(profiles_api).to receive(:bulk_subscribe_profiles_with_http_info).and_return([nil, 202, {}])

      integration.subscribe('ada@example.com')

      expect(lines.last).to match(%r{\A\[Klaviyo\] POST /api/profile-subscription-bulk-create-jobs -> 202 \(\d+ms\)\z})
      expect(lines.join).not_to include('ada@example.com')
    end
  end

  # Recorded against a Klaviyo test account (Phase 8); see spec/support/klaviyo_helpers.rb.
  describe 'against Klaviyo' do
    describe '#can_connect?' do
      it 'connects with a valid key and list', vcr: { cassette_name: 'connect_valid' } do
        expect(recording_integration.can_connect?).to be(true)
      end

      it 'refuses an invalid key', vcr: { cassette_name: 'connect_bad_key' } do
        integration = recording_integration(key: 'pk_not_a_real_key')

        expect(integration.can_connect?).to be(false)
        expect(integration.connection_error_message).to be_present
      end

      it 'refuses a key without lists:read', vcr: { cassette_name: 'connect_missing_scope' } do
        integration = recording_integration(key: klaviyo_limited_api_key)

        expect(integration.can_connect?).to be(false)
        expect(integration.connection_error_message).to be_present
      end

      it 'refuses an unknown list', vcr: { cassette_name: 'connect_unknown_list' } do
        integration = recording_integration(list_id: 'XXXXXX')

        expect(integration.can_connect?).to be(false)
        expect(integration.connection_error_message).to be_present
      end
    end

    describe '#import_profile' do
      let(:integration) { recording_integration }

      def profile(email, external_id)
        SpreeKlaviyo::Profile.new(email: email, external_id: external_id, first_name: 'Klaviyo', last_name: 'Test')
      end

      it 'creates a profile', vcr: { cassette_name: 'import_profile_create' } do
        expect { integration.import_profile(profile(klaviyo_test_address('create'), "cus_#{SecureRandom.hex(4)}")) }.
          not_to raise_error
      end

      it 'keeps one profile when the email changes', vcr: { cassette_name: 'import_profile_email_change' } do
        external_id = "cus_#{SecureRandom.hex(4)}"
        integration.import_profile(profile(klaviyo_test_address('before'), external_id))

        expect { integration.import_profile(profile(klaviyo_test_address('after'), external_id)) }.not_to raise_error
      end

      # Confirmation 1: the external id outranks the email, so a 1.x profile
      # is never matched by email alone.
      it 'creates a second profile when the email holds another external id',
         vcr: { cassette_name: 'import_profile_external_id_mismatch' } do
        address = klaviyo_test_address('mismatch')
        first = integration.import_profile(profile(address, "cus_#{SecureRandom.hex(4)}"))
        second = integration.import_profile(profile(address, "cus_#{SecureRandom.hex(4)}"))

        expect(second.dig(:data, :id)).not_to eq(first.dig(:data, :id))
        expect(second.dig(:data, :attributes, :email)).to eq(first.dig(:data, :attributes, :email))
      end

      # Confirmation 2: Klaviyo answers 200 rather than a conflict.
      it 'moves the email to the profile holding the external id',
         vcr: { cassette_name: 'import_profile_identifier_conflict' } do
        address_a = klaviyo_test_address('conflict-a')
        external_id_y = "cus_#{SecureRandom.hex(4)}"
        integration.import_profile(profile(address_a, "cus_#{SecureRandom.hex(4)}"))
        holder = integration.import_profile(profile(klaviyo_test_address('conflict-b'), external_id_y))

        moved = integration.import_profile(profile(address_a, external_id_y))

        expect(moved.dig(:data, :id)).to eq(holder.dig(:data, :id))
      end

      # A guest's profile carries no external id, so registering must not split the person.
      it 'gives a guest profile the external id when the guest registers', vcr: { cassette_name: 'import_profile_guest_registers' } do
        address = klaviyo_test_address('guest')
        guest = integration.import_profile(SpreeKlaviyo::Profile.new(email: address))

        registered = integration.import_profile(profile(address, "cus_#{SecureRandom.hex(4)}"))

        expect(registered.dig(:data, :id)).to eq(guest.dig(:data, :id))
      end
    end

    describe 'subscriptions' do
      let(:integration) { recording_integration }

      it 'subscribes an address', vcr: { cassette_name: 'subscribe' } do
        expect { integration.subscribe(klaviyo_test_address('subscribe')) }.not_to raise_error
      end

      # Confirmation 3, read in the inbox: each sign-up got its own confirmation.
      it 'accepts a second sign-up while the first is unconfirmed', vcr: { cassette_name: 'subscribe_pending_again' } do
        address = klaviyo_test_address('pending')
        integration.subscribe(address)

        expect { integration.subscribe(address) }.not_to raise_error
      end

      it 'unsubscribes an address', vcr: { cassette_name: 'unsubscribe' } do
        address = klaviyo_test_address('unsubscribe')
        integration.subscribe(address)

        expect { integration.unsubscribe(address) }.not_to raise_error
      end
    end

    describe '#create_event' do
      let(:integration) { recording_integration }
      let(:order) do
        create(:completed_order_with_totals, store: store).tap do |record|
          record.update_column(:email, klaviyo_test_address('events'))
        end
      end

      it 'sends Placed Order', vcr: { cassette_name: 'event_placed_order' } do
        expect { integration.create_event(SpreeKlaviyo::MetricEvent.placed_order(order, notify_customer: true)) }.not_to raise_error
      end

      it 'sends Ordered Product', vcr: { cassette_name: 'event_ordered_product' } do
        expect { integration.create_event(SpreeKlaviyo::MetricEvent.ordered_product(order.line_items.first)) }.not_to raise_error
      end

      it 'sends Fulfilled Order', vcr: { cassette_name: 'event_fulfilled_order' } do
        fulfillment = order.fulfillments.first
        fulfillment.update_columns(fulfilled_at: Time.current)

        expect { integration.create_event(SpreeKlaviyo::MetricEvent.fulfilled_order(fulfillment, notify_customer: true)) }.
          not_to raise_error
      end

      it 'sends Canceled Order', vcr: { cassette_name: 'event_canceled_order' } do
        order.update_columns(canceled_at: Time.current)

        expect { integration.create_event(SpreeKlaviyo::MetricEvent.canceled_order(order, notify_customer: true)) }.not_to raise_error
      end

      it 'sends Return Refunded', vcr: { cassette_name: 'event_return_refunded' } do
        return_record = create(:received_return, store: store, order: order)
        create(:store_credit, originator: return_record, amount: 10)
        event = SpreeKlaviyo::MetricEvent.return_refunded(return_record, event_id: SecureRandom.uuid, published_at: Time.current)

        expect { integration.create_event(event) }.not_to raise_error
      end

      # Read in the account, not in the 202: the event joined the older of the two profiles.
      it 'accepts an event for an email two profiles share', vcr: { cassette_name: 'event_shared_email' } do
        address = klaviyo_test_address('shared-event')
        2.times { integration.import_profile(SpreeKlaviyo::Profile.new(email: address, external_id: "cus_#{SecureRandom.hex(4)}")) }
        order.update_column(:email, address)

        expect { integration.create_event(SpreeKlaviyo::MetricEvent.placed_order(order, notify_customer: true)) }.not_to raise_error
      end
    end

    describe '#request_profile_deletion' do
      it 'requests the deletion', vcr: { cassette_name: 'request_profile_deletion' } do
        integration = recording_integration
        address = klaviyo_test_address('erasure')
        integration.import_profile(SpreeKlaviyo::Profile.new(email: address))

        expect { integration.request_profile_deletion(address) }.not_to raise_error
      end

      # Read in the account once Klaviyo's deletion job ran: both profiles were deleted.
      it 'requests the deletion of an email two profiles share', vcr: { cassette_name: 'request_profile_deletion_shared_email' } do
        integration = recording_integration
        address = klaviyo_test_address('shared-erasure')
        2.times { integration.import_profile(SpreeKlaviyo::Profile.new(email: address, external_id: "cus_#{SecureRandom.hex(4)}")) }

        expect { integration.request_profile_deletion(address) }.not_to raise_error
      end

      it 'is refused for a key without data-privacy:write', vcr: { cassette_name: 'request_profile_deletion_missing_scope' } do
        integration = recording_integration(key: klaviyo_limited_api_key)

        expect { integration.request_profile_deletion(klaviyo_test_address('erasure-scope')) }.
          to raise_error(KlaviyoAPI::ApiError) { |error| expect(error.code).to eq(403) }
      end
    end
  end
end
