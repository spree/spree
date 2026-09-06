require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::SellersController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:seller) { create(:seller, store: store, name: 'Sparks Audio', contact_email: 'hello@sparks.example') }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'lists the store sellers' do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      row = json_response['data'].first
      expect(row['id']).to start_with('sel_')
      expect(row['name']).to eq('Sparks Audio')
      expect(row['status']).to eq('pending')
    end

    it "hides another marketplace's sellers" do
      other = create(:seller, store: create(:store))

      get :index, as: :json

      expect(json_response['data'].map { |row| row['id'] }).not_to include(other.prefixed_id)
    end

    # The team is preloaded and counted in Ruby; the catalog is counted in SQL,
    # so a seller with thousands of products never loads them just to show a
    # number.
    it 'never loads a seller catalog to count it' do
      seller.products << create(:product, store: store)
      3.times { create(:seller, store: store) }

      product_row_loads = 0
      team_counts = 0
      subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
        sql = payload[:sql]
        product_row_loads += 1 if sql.match?(/spree_products/i) && !sql.match?(/SELECT COUNT/i)
        team_counts += 1 if sql.match?(/SELECT COUNT/i) && sql.match?(/spree_role_users/i)
      end

      get :index, as: :json

      ActiveSupport::Notifications.unsubscribe(subscriber)
      expect(product_row_loads).to eq(0)
      expect(team_counts).to eq(0)
    end

    it 'says whether a seller can be bought from right now' do
      seller.update!(status: 'approved', holiday_mode_until: 2.weeks.from_now)

      get :index, as: :json

      row = json_response['data'].first
      expect(row['on_holiday']).to be(true)
      expect(row['sellable']).to be(false)
    end
  end

  # A requirement kind may ask a payment provider whether a seller can be
  # paid. One call is fine for one seller; a page of them would make the list
  # as slow as the operator's connection.
  describe 'asking the payout provider' do
    before do
      Spree::SellerRequirements::PayoutAccount.create!(store: store, name: 'Payout account', required: true)
    end

    it 'is not done per row on the list' do
      create(:seller, store: store)
      expect_any_instance_of(Spree::PayoutProvider::System).not_to receive(:onboarded?)

      get :index, as: :json

      expect(response).to have_http_status(:ok)
    end

    # Here the operator is looking at exactly this seller, so the answer has
    # to be the current one — the checklist is eager-loaded either way, which
    # is why that cannot be the signal.
    it 'is done for the seller being looked at' do
      expect_any_instance_of(Spree::PayoutProvider::System).to receive(:onboarded?).at_least(:once).and_return(true)

      get :show, params: { id: seller.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
    end

    # The checklist is where staff decide whether to admit a seller, so a
    # stale answer here is the one that costs something — a seller who has
    # finished with Stripe left looking unfinished, or the reverse.
    it 'is done for the checklist staff read' do
      expect_any_instance_of(Spree::PayoutProvider::System).to receive(:onboarded?).at_least(:once).and_return(true)

      get :onboarding, params: { id: seller.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET #show' do
    it 'returns the seller profile' do
      get :show, params: { id: seller.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['contact_email']).to eq('hello@sparks.example')
    end

    it "404s on another marketplace's seller" do
      other = create(:seller, store: create(:store))

      get :show, params: { id: other.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #create' do
    it 'opens a seller record awaiting invitation' do
      post :create, params: { name: 'Northwind Books', contact_email: 'hi@northwind.example' }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['status']).to eq('pending')
      expect(json_response['slug']).to eq('northwind-books')
    end

    it 'refuses a slug already taken in this marketplace' do
      post :create, params: { name: 'Sparks Audio' }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'PATCH #update' do
    it 'edits the profile and the settlement configuration' do
      patch :update, params: {
        id: seller.prefixed_id,
        billing_email: 'billing@sparks.example',
        payouts_schedule_interval: 'weekly',
        minimum_payout_amount: '25.0'
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(seller.reload.billing_email).to eq('billing@sparks.example')
      expect(seller.payouts_schedule_interval).to eq('weekly')
    end

    # The transitions are workflows; a PATCH that moved status would skip the
    # mail, the payout provisioning and the extension hooks.
    it 'ignores a status sent through mass assignment' do
      patch :update, params: { id: seller.prefixed_id, status: 'approved' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(seller.reload).to be_pending
    end

    # Written as `about`, read back as both the plain text and the markup —
    # the column holds HTML either way.
    it 'keeps the markup in the description' do
      patch :update, params: { id: seller.prefixed_id, about: '<p>Independent <em>hi-fi</em>.</p>' },
                     as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['about_html']).to include('<em>hi-fi</em>')
      expect(json_response['about']).to eq('Independent hi-fi.')
    end

    it 'strips scripts out of the description' do
      patch :update, params: { id: seller.prefixed_id, about: '<p>Hi</p><script>alert(1)</script>' },
                     as: :json

      expect(seller.reload.about_html).not_to include('script')
    end

    # An address carries no store of its own, so an id would bind an arbitrary
    # row — and the serializer renders it back in full, customer and all.
    it 'refuses to bind an address by id' do
      victim = create(:user)
      foreign = create(:address, customer: victim, address1: '99 Secret Lane')

      patch :update, params: { id: seller.prefixed_id, billing_address_id: foreign.prefixed_id },
                     as: :json

      expect(seller.reload.billing_address_id).to be_nil
      expect(json_response).not_to have_key('billing_address')
    end

    it 'ignores a raw integer address id too' do
      foreign = create(:address, customer: create(:user))

      patch :update, params: { id: seller.prefixed_id, billing_address_id: foreign.id.to_s }, as: :json

      expect(seller.reload.billing_address_id).to be_nil
    end

    it 'creates the seller its own address from nested attributes' do
      patch :update, params: {
        id: seller.prefixed_id,
        billing_address: { company: 'Sparks Trading Ltd', address1: '1 Seller Way',
                           city: 'London', postal_code: 'EC1A 1BB', country_code: 'GB', phone: '555' }
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(seller.reload.billing_address.address1).to eq('1 Seller Way')
      expect(json_response['billing_address']['city']).to eq('London')
    end

    # The dashboard direct-uploads the file, then sends the resulting signed id.
    it 'attaches branding from a signed id' do
      blob = ActiveStorage::Blob.create_and_upload!(
        io: File.open(Spree::Core::Engine.root.join('spec', 'fixtures', 'thinking-cat.jpg')),
        filename: 'thinking-cat.jpg', content_type: 'image/jpeg'
      )

      patch :update, params: { id: seller.prefixed_id, logo: blob.signed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(seller.reload.logo).to be_attached
      expect(json_response['logo_url']).to be_present
    end

    it 'attaches a cover photo the same way' do
      blob = ActiveStorage::Blob.create_and_upload!(
        io: File.open(Spree::Core::Engine.root.join('spec', 'fixtures', 'thinking-cat.jpg')),
        filename: 'cover.jpg', content_type: 'image/jpeg'
      )

      patch :update, params: { id: seller.prefixed_id, cover_photo: blob.signed_id }, as: :json

      expect(seller.reload.cover_photo).to be_attached
      expect(json_response['cover_photo_url']).to be_present
    end

    it 'purges the logo when logo is set to null' do
      seller.logo.attach(
        io: File.new(Spree::Core::Engine.root.join('spec', 'fixtures', 'thinking-cat.jpg')),
        filename: 'thinking-cat.jpg'
      )

      patch :update, params: { id: seller.prefixed_id, logo: nil }, as: :json

      expect(response).to have_http_status(:ok)
      expect(seller.reload.logo).not_to be_attached
    end
  end

  # Spree::Seller includes HasCustomFields and the controller permits them, so
  # the nested endpoints have to exist for a client to read or write one.
  describe 'custom fields' do
    it 'mounts the nested custom_fields resource' do
      expect(get: "/api/v3/admin/sellers/#{seller.prefixed_id}/custom_fields").to be_routable
    end
  end

  describe 'POST #invite' do
    it "invites someone into the seller's own team" do
      post :invite, params: { id: seller.prefixed_id, email: 'seller@example.com' }, as: :json

      expect(response).to have_http_status(:created)
      expect(seller.reload).to be_invited
      expect(seller.invitations.last.role.resource).to eq(seller)
    end

    it 'refuses a role from another team' do
      store_role = Spree::Role.default_admin_role(store)

      post :invite, params: { id: seller.prefixed_id, email: 'seller@example.com', role_id: store_role.prefixed_id },
                    as: :json

      expect(response).to have_http_status(:not_found)
      expect(seller.reload).to be_pending
    end
  end

  describe 'PATCH #approve' do
    it 'lets an applicant under review trade' do
      seller.update!(status: 'ready_for_review')

      patch :approve, params: { id: seller.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(seller.reload).to be_approved
    end

    it 'refuses one that has not applied yet' do
      patch :approve, params: { id: seller.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'PATCH #suspend' do
    before { seller.update!(status: 'approved') }

    it 'stops a trading seller and keeps the reason' do
      patch :suspend, params: { id: seller.prefixed_id, reason: 'Counterfeit goods' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(seller.reload).to be_suspended
      expect(seller.metadata['suspension_reason']).to eq('Counterfeit goods')
    end
  end

  describe 'PATCH #reject' do
    it 'turns down an applicant' do
      seller.update!(status: 'ready_for_review')

      patch :reject, params: { id: seller.prefixed_id, reason: 'Incomplete paperwork' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(seller.reload).to be_rejected
    end

    it 'refuses one already trading — suspension is the right move there' do
      seller.update!(status: 'approved')

      patch :reject, params: { id: seller.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'DELETE #destroy' do
    # A seller's roles refuse deletion while anyone holds them. That guard is
    # for deleting a role on its own; when the whole seller goes, its team goes
    # with it — otherwise an invited seller could never be removed.
    it 'removes a seller that has already been invited' do
      Spree::Sellers::Invite.call(seller: seller, email: 'seller@example.com',
                                  inviter: create(:admin_user))

      delete :destroy, params: { id: seller.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(Spree::Seller.find_by(id: seller.id)).to be_nil
      expect(Spree::Role.where(resource: seller)).to be_empty
    end

    it 'removes the seller but keeps their catalog' do
      product = create(:product, store: store, seller: seller)

      delete :destroy, params: { id: seller.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(product.reload.seller_id).to be_nil
    end
  end
end
