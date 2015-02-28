require 'spec_helper'

describe "Version", type: :request do
  let!(:countries) { 2.times.map { create :country } }

  describe "/api" do
    it "can render" do
      get "/api/countries"
      expect(response).to have_http_status 200
    end
  end
end
