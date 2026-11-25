require 'spec_helper'

RSpec.describe Spree::Api::V3::ErrorHandler, type: :controller do
  render_views

  # Raises each kind of failure the error handler rescues, so what it reports
  # to the error tracker can be checked one failure at a time.
  controller(Spree::Api::V3::Store::BaseController) do
    def record_invalid
      Spree::TaxCategory.new.save!
    end

    def parameter_missing
      params.require(:missing)
    end

    def gateway_error
      raise Spree::Core::GatewayError, 'The gateway is down'
    end
  end

  include_context 'API v3 Store'

  before do
    routes.draw do
      post 'record_invalid' => 'spree/api/v3/store/base#record_invalid'
      post 'parameter_missing' => 'spree/api/v3/store/base#parameter_missing'
      post 'gateway_error' => 'spree/api/v3/store/base#gateway_error'
    end
    request.headers['X-Spree-Api-Key'] = api_key.token
    allow(Rails.error).to receive(:report)
  end

  # A failed validation is the API doing its job: the client is told what to
  # fix, and the error tracker is kept for faults on our side.
  it 'answers a failed validation with 422 and its field errors without reporting it' do
    post :record_invalid

    expect(response).to have_http_status(:unprocessable_content)
    expect(json_response['error']['code']).to eq('validation_error')
    expect(json_response['error']['details']['name']).to eq(["can't be blank"])
    expect(Rails.error).not_to have_received(:report)
  end

  it 'answers a missing parameter with 400 without reporting it' do
    post :parameter_missing

    expect(response).to have_http_status(:bad_request)
    expect(json_response['error']['code']).to eq('parameter_missing')
    expect(Rails.error).not_to have_received(:report)
  end

  it 'still reports a gateway failure' do
    post :gateway_error

    expect(response).to have_http_status(:unprocessable_content)
    expect(Rails.error).to have_received(:report).with(kind_of(Spree::Core::GatewayError), hash_including(source: 'spree.api.v3'))
  end
end
