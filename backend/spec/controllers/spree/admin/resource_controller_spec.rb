require 'spec_helper'

module Spree
  module Admin
    class WidgetsController < Spree::Admin::ResourceController
      prepend_view_path('spec/test_views')

      def model_class
        Widget
      end
    end
  end
end

describe Spree::Admin::WidgetsController, :type => :controller do
  stub_authorization!

  after(:all) do
    # Spree::Core::Engine.routes.reload_routes!
    Rails.application.reload_routes!
  end

  with_model 'Widget' do
    table do |t|
      t.string :name
      t.integer :position
      t.timestamps null: false
    end

    model do
      acts_as_list
      validates :name, presence: true
    end
  end

  before do
    Spree::Core::Engine.routes.draw do
      namespace :admin do
        resources :widgets do
          post :update_positions, on: :member
        end
      end
    end
    stub_const('Spree::Widget', Widget)
  end

  describe '#new' do
    subject do
      spree_get :new
    end

    it 'succeeds' do
      subject
      expect(response).to be_success
    end
  end

  describe '#edit' do
    let(:widget) { Widget.create!(name: 'a widget') }

    subject do
      spree_get :edit, id: widget.to_param
    end

    it 'succeeds' do
      subject
      expect(response).to be_success
    end
  end

  describe '#create' do
    let(:params) do
      {widget: {name: 'a widget'}}
    end

    subject { spree_post :create, params }

    it 'creates the resource' do
      expect { subject }.to change { Widget.count }.by(1)
    end

    context 'failure' do
      let(:params) do
        {widget: {name: ''}} # blank name generates an error
      end

      it 'sets a flash error' do
        subject
        expect(flash[:error]).to eq assigns(:widget).errors.full_messages.join(', ')
      end
    end

    context 'without any parameters' do
      let(:params) { {} }

      before do
        allow_any_instance_of(Widget).to receive(:name).and_return('some name')
      end

      it 'creates the resource' do
        expect { subject }.to change { Widget.count }.by(1)
      end
    end
  end

  describe '#update' do
    let(:widget) { Widget.create!(name: 'a widget') }

    let(:params) do
      {
        id: widget.to_param,
        widget: {name: 'widget renamed'},
      }
    end

    subject { spree_put :update, params }

    it 'updates the resource' do
      expect { subject }.to change { widget.reload.name }.from('a widget').to('widget renamed')
    end

    context 'failure' do
      let(:params) do
        {
          id: widget.to_param,
          widget: {name: ''}, # a blank name will trigger a validation error
        }
      end

      it 'sets a flash error' do
        subject
        expect(flash[:error]).to eq assigns(:widget).errors.full_messages.join(', ')
      end
    end
  end

  describe '#destroy' do
    let!(:widget) { Widget.create!(name: 'a widget') }
    let(:params) { {id: widget.id} }

    subject {
      spree_delete :destroy, params
    }

    it 'destroys the resource' do
      expect { subject }.to change { Widget.count }.from(1).to(0)
    end
  end

  describe '#update_positions' do
    let(:widget_1) { Widget.create!(name: 'widget 1', position: 1) }
    let(:widget_2) { Widget.create!(name: 'widget 2', position: 2) }

    subject do
      spree_post :update_positions, id: widget_1.to_param,
        positions: { widget_1.id => '2', widget_2.id => '1' }, format: 'js'
    end

    it 'updates the position of widget 1' do
      expect { subject }.to change { widget_1.reload.position }.from(1).to(2)
    end

    it 'updates the position of widget 2' do
      expect { subject }.to change { widget_2.reload.position }.from(2).to(1)
    end

    it 'touches updated_at' do
      expect { subject }.to change { widget_1.reload.updated_at }
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

describe Spree::Admin::Submodule::PostsController, type: :controller do
  stub_authorization!

  after(:all) do
    # Spree::Core::Engine.routes.reload_routes!
    Rails.application.reload_routes!
  end

  with_table 'spree_posts' do |t|
    t.string :name
    t.integer :position
    t.timestamps null: false
  end

  before do
    Spree::Core::Engine.routes.draw do
      namespace :admin do
        namespace :submodule do
          resources :posts
        end
      end
    end
  end

  describe '#new' do
    subject do
      spree_get :new
    end

    it 'succeeds' do
      subject
      expect(response).to be_success
    end
  end

  describe '#edit' do
    let(:submodule_post) { Spree::Submodule::Post.create!(name: 'a post') }

    subject do
      spree_get :edit, id: submodule_post.to_param
    end

    it 'succeeds' do
      subject
      expect(response).to be_success
    end
  end

  describe '#create' do
    let(:params) do
      { submodule_post: { name: 'a post' } }
    end

    subject { spree_post :create, params }

    it 'creates the resource' do
      expect { subject }.to change { Spree::Submodule::Post.count }.by(1)
    end
  end

  describe '#update' do
    let(:post) { Spree::Submodule::Post.create!(name: 'a post') }

    let(:params) do
      { id: post.to_param, submodule_post: { name: 'post renamed' } }
    end

    subject { spree_put :update, params }

    it 'updates the resource' do
      expect { subject }.to change { post.reload.name }.from('a post').to('post renamed')
    end
  end

  describe '#destroy' do
    let!(:post) { Spree::Submodule::Post.create!(name: 'a post') }
    let(:params) { { id: post.id } }

    subject { spree_delete :destroy, params }

    it 'destroys the resource' do
      expect { subject }.to change { Spree::Submodule::Post.count }.from(1).to(0)
    end
  end
end

