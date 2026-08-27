require 'spec_helper'

RSpec.describe Spree::Api::V3::Seller::ProfileController, type: :controller do
  render_views

  include_context 'API v3 Seller'

  # The seeded role, not the shared context's narrow one — this is what a
  # seller actually holds on their own seller.
  let(:seller_user) do
    create(:admin_user, :without_admin_role).tap { |user| seller.add_user(user) }
  end
  let(:token) do
    Spree::Api::V3::TestingSupport.generate_jwt(
      seller_user, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_SELLER
    )
  end

  before do
    request.headers['Authorization'] = "Bearer #{token}"
    request.headers['X-Spree-Seller-Id'] = seller.prefixed_id
  end

  describe 'GET #show' do
    it 'returns the seller their own record' do
      get :show, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(seller.prefixed_id)
      expect(json_response['name']).to eq(seller.name)
    end

    # A seller should know they are suspended, and what they are owed on.
    it 'shows their standing and settlement terms' do
      get :show, as: :json

      expect(json_response).to include('status', 'sellable', 'tax_remittance',
                                       'payouts_schedule_interval')
    end

    # There is no id in the request to tamper with — the seller comes from the
    # token's membership. This is the whole point of a singular resource here.
    it 'ignores any seller named in the params' do
      other = create(:seller, :approved, store: store)

      get :show, params: { id: other.prefixed_id }, as: :json

      expect(json_response['id']).to eq(seller.prefixed_id)
    end
  end

  describe 'PATCH #update' do
    it 'edits presentation and contact details' do
      patch :update, params: { name: 'Sparks Audio Ltd', contact_email: 'hello@sparks.example' },
                     as: :json

      expect(response).to have_http_status(:ok)
      expect(seller.reload.name).to eq('Sparks Audio Ltd')
      expect(seller.contact_email).to eq('hello@sparks.example')
    end

    it 'writes its billing address inline' do
      patch :update, params: {
        billing_address: { company: 'Sparks Trading Ltd', address1: '1 Seller Way',
                           city: 'London', postal_code: 'EC1A 1BB', country_code: 'GB',
                           phone: '555' }
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(seller.reload.billing_address.address1).to eq('1 Seller Way')
    end

    # Returns go to a stock location, which has its own endpoint — a seller
    # cannot write one through the profile.
    it 'does not accept a returns address' do
      patch :update, params: {
        returns_address: { address1: '1 Seller Way', city: 'London', country_code: 'GB' }
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(seller.reload.returns_address).to be_nil
    end

    # The lifecycle belongs to the operator's workflows. A seller approving
    # themselves would skip the mail, the payouts and every extension hook.
    # A status the seller does not already hold, so this fails if `status`
    # ever becomes permitted — sending the one they are on would pass either
    # way and prove nothing.
    it 'refuses to move its own status' do
      patch :update, params: { status: 'suspended' }, as: :json

      expect(seller.reload).to be_approved
    end

    it 'cannot change its own settlement terms' do
      patch :update, params: { tax_remittance: 'platform', minimum_payout_amount: '9999' },
                     as: :json

      expect(seller.reload.tax_remittance).to eq('seller')
      expect(seller.minimum_payout_amount).to be_nil
    end

    # Renaming the storefront address breaks every link pointing at it.
    # Accepting terms is a profile write, not an endpoint of its own — the
    # AcceptTerms requirement reads the stamp this sets.
    it 'stamps the moment the seller accepts the terms' do
      seller.update!(terms_accepted_at: nil)

      expect {
        patch :update, params: { accept_terms: true }, as: :json
      }.to change { seller.reload.terms_accepted_at }.from(nil)

      expect(response).to have_http_status(:ok)
    end

    # The stamp records that it happened; sending false does not unmake it.
    it 'does not let a seller un-accept the terms' do
      accepted = 3.days.ago.change(usec: 0)
      seller.update!(terms_accepted_at: accepted)

      patch :update, params: { accept_terms: false }, as: :json

      expect(seller.reload.terms_accepted_at).to be_within(1.second).of(accepted)
    end
    # A marketplace that rewrites its terms advances the requirement's
    # `terms_effective_from`, which puts everyone who accepted before that
    # date back on the checklist. A seller who could not re-accept would be
    # stuck there with nothing to click.
    it 'lets a seller accept revised terms' do
      seller.update!(terms_accepted_at: 1.year.ago)

      expect {
        patch :update, params: { accept_terms: true }, as: :json
      }.to change { seller.reload.terms_accepted_at }

      expect(seller.terms_accepted_at).to be_within(5.seconds).of(Time.current)
    end

    it 'cannot change its own slug' do
      original = seller.slug

      patch :update, params: { slug: 'something-else' }, as: :json

      expect(seller.reload.slug).to eq(original)
    end

    it 'reports validation errors' do
      patch :update, params: { name: '' }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'another seller' do
    it 'cannot act as a seller they do not belong to' do
      other = create(:seller, :approved, store: store)

      request.headers['X-Spree-Seller-Id'] = other.prefixed_id
      get :show, as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end
  # Custom fields on Spree::Seller are the operator's schema, and some are
  # theirs alone. A seller fills in what onboarding asked them for.
  describe 'PATCH #update custom fields' do
    let(:asked_for) do
      create(:custom_field_definition, resource_type: 'Spree::Seller', namespace: 'seller',
                                       key: 'vat_number', label: 'VAT number')
    end
    let(:operator_only) do
      create(:custom_field_definition, resource_type: 'Spree::Seller', namespace: 'seller',
                                       key: 'risk_note', label: 'Risk note')
    end
    let!(:requirement) do
      create(:required_custom_fields_requirement, store: store).tap do |req|
        req.custom_field_definitions << asked_for
      end
    end

    it 'writes a field the checklist asks for' do
      patch :update, params: {
        custom_fields: [{ custom_field_definition_id: asked_for.prefixed_id, value: 'GB123456789' }]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(seller.reload.custom_fields.find_by(custom_field_definition: asked_for).value).
        to eq('GB123456789')
    end

    # The nested-attributes writer builds a row every time, so a seller
    # correcting a value they had already saved hit the uniqueness index and
    # got "has already been taken". The upserting writer is the right one.
    it 'updates a field the seller already answered' do
      patch :update, params: {
        custom_fields: [{ custom_field_definition_id: asked_for.prefixed_id, value: 'GB111' }]
      }, as: :json
      patch :update, params: {
        custom_fields: [{ custom_field_definition_id: asked_for.prefixed_id, value: 'GB222' }]
      }, as: :json

      expect(response).to have_http_status(:ok)
      fields = seller.reload.custom_fields.where(custom_field_definition: asked_for)
      expect(fields.count).to eq(1)
      expect(fields.first.value).to eq('GB222')
    end

    it 'ignores a field nothing asked them for' do
      patch :update, params: {
        custom_fields: [{ custom_field_definition_id: operator_only.prefixed_id, value: 'sneaky' }]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(seller.reload.custom_fields.find_by(custom_field_definition: operator_only)).to be_nil
    end
  end

  # The business identity a commission invoice is made out to — legal name,
  # registration number, and the VAT number EU reverse charge turns on.
  describe 'PATCH #update business identity' do
    it 'writes the legal name and registration number' do
      patch :update, params: {
        legal_name: 'Sparks Trading Ltd', registration_number: '01234567'
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(seller.reload.legal_name).to eq('Sparks Trading Ltd')
      expect(seller.registration_number).to eq('01234567')
    end

    let(:vat_number) { eu_vat_number(0) }
    let(:corrected_vat_number) { eu_vat_number(1) }

    it 'records a tax registration' do
      patch :update, params: { tax_identifier: { kind: 'eu_vat', value: vat_number } }, as: :json

      expect(response).to have_http_status(:ok)
      identifier = seller.reload.tax_identifiers.find_by(kind: 'eu_vat')
      expect(identifier.value).to eq(vat_number)
    end

    # One per kind, so correcting the number replaces it rather than stacking
    # a second row the model would refuse.
    it 'corrects a registration rather than adding a second' do
      patch :update, params: { tax_identifier: { kind: 'eu_vat', value: vat_number } }, as: :json
      patch :update, params: { tax_identifier: { kind: 'eu_vat', value: corrected_vat_number } }, as: :json

      expect(response).to have_http_status(:ok)
      identifiers = seller.reload.tax_identifiers.where(kind: 'eu_vat')
      expect(identifiers.count).to eq(1)
      expect(identifiers.first.value).to eq(corrected_vat_number)
    end

    # The seller panel lets the kind change, so a seller moving from one regime
    # to another must end up holding the new registration and not both.
    it 'replaces the registration when the seller changes its kind' do
      patch :update, params: { tax_identifier: { kind: 'eu_vat', value: vat_number } }, as: :json
      patch :update, params: { tax_identifier: { kind: 'gb_vat', value: 'GB123456789' } }, as: :json

      expect(response).to have_http_status(:ok)
      identifiers = seller.reload.tax_identifiers
      expect(identifiers.map(&:kind)).to contain_exactly('gb_vat')
      expect(identifiers.first.value).to eq('GB123456789')
    end

    # Silently dropping it would answer 200 to a number that was never stored.
    it 'refuses a malformed number rather than discarding it quietly' do
      patch :update, params: { tax_identifier: { kind: 'eu_vat', value: 'DE123' } }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(seller.reload.tax_identifiers.where(kind: 'eu_vat')).to be_empty
    end

    # A 422 the seller reads as "nothing saved" must mean it.
    it 'keeps the rest of the form out of the database when the number is refused' do
      original_name = seller.name

      patch :update, params: { name: 'Renamed Seller',
                               tax_identifier: { kind: 'eu_vat', value: 'DE123' } }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(seller.reload.name).to eq(original_name)
    end

    it 'removes it when the seller clears the number' do
      patch :update, params: { tax_identifier: { kind: 'eu_vat', value: vat_number } }, as: :json
      patch :update, params: { tax_identifier: { kind: 'eu_vat', value: '' } }, as: :json

      expect(seller.reload.tax_identifiers.where(kind: 'eu_vat')).to be_empty
    end

    it 'serializes them back' do
      seller.tax_identifiers.create!(kind: 'eu_vat', value: vat_number)

      get :show, as: :json

      expect(json_response['tax_identifiers'].first).to include(
        'kind' => 'eu_vat', 'value' => vat_number
      )
    end
  end

  # The profile inherits its policies association from the store serializer,
  # which renders a policy without `created_at` — a shape the seller SDK's
  # generated type and this branch's OpenAPI schema both say is wrong.
  describe 'policies' do
    it 'renders them in the seller shape, with timestamps' do
      seller.policies.create!(name: 'Returns Policy', body: '<p>Thirty days.</p>')

      get :show, params: { expand: 'policies' }, as: :json

      policy = json_response['policies'].first
      expect(policy['name']).to eq('Returns Policy')
      expect(policy['created_at']).to be_present
      expect(policy['updated_at']).to be_present
    end
  end

end
