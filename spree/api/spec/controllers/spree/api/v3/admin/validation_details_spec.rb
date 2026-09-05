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
    probe = Spree::Api::V3::Admin::ValidationProbe.new(quantity: -1)
    probe.validate
    probe.errors.add(:base, 'Something specific went wrong')
    probe.errors
  end
end

class Spree::Api::V3::Admin::ValidationProbe
  include ActiveModel::Model

  attr_accessor :name, :quantity

  validates :name, presence: true
  validates :quantity, numericality: { greater_than: 0 }
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
      expect(details['name']).to eq([{ 'code' => 'blank', 'message' => "can't be blank" }])
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
        [{ 'code' => nil, 'message' => 'Something specific went wrong' }]
      )
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
