require 'spec_helper'

module Spree
  module Admin
    class DummyModelsController < Spree::Admin::ResourceController
      def model_class
        Spree::DummyModel
      end

      def permitted_resource_params
        params.require(:dummy_model).permit(:name)
      end
    end
  end
end

describe Spree::Admin::DummyModelsController, type: :controller do
  stub_authorization!

  after(:all) do
    Rails.application.reload_routes!
  end

  before do
    Spree::Core::Engine.routes.draw do
      namespace :admin do
        resources :dummy_models
      end
    end
  end

  describe '#create' do
    subject { post :create, params: params }

    let(:params) do
      { dummy_model: { name: 'a dummy_model' } }
    end

    it 'creates the resource' do
      expect { subject }.to change { Spree::DummyModel.count }.by(1)
    end
  end

  describe '#update' do
    subject { put :update, params: params }

    let(:dummy_model) { Spree::DummyModel.create!(name: 'a dummy_model') }

    let(:params) do
      {
        id: dummy_model.to_param,
        dummy_model: { name: 'dummy_model renamed' }
      }
    end

    it 'updates the resource' do
      expect { subject }.to change { dummy_model.reload.name }.from('a dummy_model').to('dummy_model renamed')
    end
  end

  describe '#destroy' do
    subject do
      delete :destroy, params: params
    end

    let!(:dummy_model) { Spree::DummyModel.create!(name: 'a dummy_model') }
    let(:params) { { id: dummy_model.id } }

    it 'destroys the resource' do
      expect { subject }.to change { Spree::DummyModel.count }.from(1).to(0)
    end
  end
end
