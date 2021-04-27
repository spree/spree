require 'spec_helper'

describe Spree::Admin::MenusController, type: :controller do
  stub_authorization!

  describe 'GET index' do
    it 'is ok' do
      get :index
      expect(response).to be_ok
    end
  end
end
