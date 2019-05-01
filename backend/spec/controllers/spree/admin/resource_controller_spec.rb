require 'spec_helper'

module Spree
  module Admin
    class DummyModelsController < Spree::Admin::ResourceController
      prepend_view_path('spec/test_views')

      def model_class
        Spree::DummyModel
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
        resources :dummy_models do
          post :update_positions, on: :member
        end
      end
    end
  end

  describe '#new' do
    subject do
      get :new
    end

    it 'succeeds' do
      subject
      expect(response).to be_successful
    end
  end

  describe '#edit' do
    subject do
      get :edit, params: { id: dummy_model.to_param }
    end

    let(:dummy_model) { Spree::DummyModel.create!(name: 'a dummy_model') }

    it 'succeeds' do
      subject
      expect(response).to be_successful
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

    context 'without any parameters' do
      let(:params) { {} }

      before do
        allow_any_instance_of(Spree::DummyModel).to receive(:name).and_return('some name')
      end

      it 'creates the resource' do
        expect { subject }.to change { Spree::DummyModel.count }.by(1)
      end
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

  describe '#update_positions' do
    subject do
      post :update_positions, params: {
        id: dummy_model_1.to_param,
        positions: { dummy_model_1.id => '2', dummy_model_2.id => '1' }, format: 'js'
      }
    end

    let(:dummy_model_1) { Spree::DummyModel.create!(name: 'dummy_model 1', position: 1) }
    let(:dummy_model_2) { Spree::DummyModel.create!(name: 'dummy_model 2', position: 2) }

    it 'updates the position of dummy_model 1' do
      expect { subject }.to change { dummy_model_1.reload.position }.from(1).to(2)
    end

    it 'updates the position of dummy_model 2' do
      expect { subject }.to change { dummy_model_2.reload.position }.from(2).to(1)
    end

    it 'touches updated_at' do
      Timecop.scale(3600) do
        expect { subject }.to change { dummy_model_1.reload.updated_at }
      end
    end
  end
end

module Spree
  module Submodule
    class Post < Spree::Base
    end
  end
  module Admin
    module Submodule
      class PostsController < Spree::Admin::ResourceController
        prepend_view_path('spec/test_views')

        def model_class
          Spree::Submodule::Post
        end
      end
    end
  end
end
