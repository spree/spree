require 'spec_helper'

# Anonymous controllers that render one deliberately-invalid record, so the
# two branches' 422 payloads can be compared side by side.
class Spree::Api::V3::Admin::ValidationProbeController < Spree::Api::V3::Admin::BaseController
  skip_scope_check!

  def create
    render_validation_error(probe_errors)
  end

  private

  def probe_errors
    probe = Spree::Api::V3::Admin::ValidationProbe.new(quantity: -1, handle: 'lower case')
    probe.validate
    probe.errors.add(:base, 'Something specific went wrong')
    # A validation may pass its own `code:` option; ActiveModel keeps it in
    # `details` alongside the error symbol.
    probe.errors.add(:sku, :taken, code: 'supplier-side', message: 'is already taken')
    # A Spree code: its copy lives under `spree.errors.messages`, where Rails
    # never looks for a default. The message is still that code's own text.
    probe.errors.add(:seller, :seller_delivery_method_provider,
                     message: Spree.t('errors.messages.seller_delivery_method_provider'))
    probe.errors
  end
end

class Spree::Api::V3::Admin::ValidationProbe
  include ActiveModel::Model

  attr_accessor :name, :quantity, :sku, :handle, :seller

  validates :name, presence: true
  validates :quantity, numericality: { greater_than: 0 }
  # Same `:invalid` code as any format check, but with its own wording — the
  # shape the `specific` flag exists to describe.
  validates :handle, format: { with: /\A[A-Z]+\z/, message: 'must be upper case letters' },
                     allow_nil: true
end

class Spree::Api::V3::Store::ValidationProbeController < Spree::Api::V3::Store::BaseController
  def create
    probe = Spree::Api::V3::Admin::ValidationProbe.new(quantity: -1)
    probe.validate
    render_validation_error(probe.errors)
  end
end

RSpec.describe Spree::Api::V3::Admin::ValidationDetails, type: :controller do
  render_views

  describe 'the Admin API' do
    controller(Spree::Api::V3::Admin::ValidationProbeController) do
      skip_scope_check!
    end

    include_context 'API v3 Admin'

    before do
      routes.draw { post 'create' => 'spree/api/v3/admin/validation_probe#create' }
      request.headers['X-Spree-Api-Key'] = secret_api_key.plaintext_token
    end

    let(:details) { json_response['error']['details'] }

    it 'names the Rails error code beside the message' do
      post :create

      expect(response).to have_http_status(:unprocessable_content)
      expect(details['name']).to eq(
        [{ 'code' => 'blank', 'message' => "can't be blank", 'specific' => false }]
      )
    end

    it "carries the validation's interpolation values so the client can build its own sentence" do
      post :create

      # `count` is what "must be greater than 0" interpolates — without it a
      # translated message cannot name the boundary it is describing.
      expect(details['quantity'].first).to include('code' => 'greater_than', 'count' => 0)
    end

    it 'reports a null code for a message added as a bare string' do
      post :create

      # Nothing to translate: the dashboard falls back to rendering `message`.
      expect(details['base']).to eq(
        [{ 'code' => nil, 'message' => 'Something specific went wrong', 'specific' => false }]
      )
    end

    it "reports the Rails error code even when the validation carries a code of its own" do
      post :create

      # The validation's own `code:` is interpolation data, not the error
      # identity — it must not displace the symbol the dashboard translates.
      expect(details['sku'].first).to include('code' => 'taken', 'message' => 'is already taken')
    end

    it 'marks a message the model worded itself, so a client keeps it' do
      post :create

      # `invalid` is generic; this message is not. A client translating the
      # code alone would replace "must be upper case letters" with "is
      # invalid", so the server says which it is.
      expect(details['handle']).to include(
        hash_including('code' => 'invalid', 'specific' => true)
      )
    end

    it 'does not mark a code whose copy Rails has no default for' do
      post :create

      # Every Spree code is this shape. `generate_message` answers a
      # "Translation missing" string for them rather than raising, so a naive
      # comparison would call all of them overrides and the dashboard would
      # skip the translations it holds.
      expect(details['seller'].first).to include(
        'code' => 'seller_delivery_method_provider', 'specific' => false
      )
    end

    it "does not mark a message that is only the code's own default" do
      post :create

      # The dashboard translates these, and must be able to tell them apart
      # from an override in a store trading in any language.
      expect(details['name'].first).to include('code' => 'blank', 'specific' => false)
    end

    it 'keeps the readable summary for clients that do not translate' do
      post :create

      expect(json_response['error']['message']).to include("Name can't be blank")
    end
  end

  describe 'the Store API' do
    controller(Spree::Api::V3::Store::ValidationProbeController) do
    end

    include_context 'API v3 Store'

    before do
      routes.draw { post 'create' => 'spree/api/v3/store/validation_probe#create' }
      request.headers['X-Spree-Api-Key'] = api_key.token
    end

    it 'keeps the flat message shape it has always had' do
      post :create

      # Deliberately unchanged: the richer shape is an Admin-only override, so
      # storefronts reading `details[attr][0]` as a string keep working.
      expect(json_response['error']['details']['name']).to eq(["can't be blank"])
    end
  end
end
