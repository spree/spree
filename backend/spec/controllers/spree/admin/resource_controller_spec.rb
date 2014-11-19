require 'spec_helper'

class WidgetsController < Spree::Admin::ResourceController
  prepend_view_path('spec/test_views')

  def model_class
    Widget
  end
end

describe WidgetsController, :type => :controller do
  stub_authorization!

  with_model 'Widget' do
    table do |t|
      t.string :name
      t.integer :position
      t.timestamps
    end

    model do
      validates :name, presence: true
    end
  end

  describe '#new' do
    it 'succeeds' do
      spree_get :new
      expect(response).to be_success
    end
  end

  describe '#edit' do
    let(:widget) { Widget.create!(name: 'a widget') }

    it 'succeeds' do
      spree_get :edit, id: widget.to_param
      expect(response).to be_success
    end
  end

  describe '#create' do
    let(:params) do
      {widget: {name: 'a widget'}}
    end

    subject { spree_post :create, params }

    context 'failure' do
      let(:params) do
        {widget: {name: ''}} # blank name generates an error
      end

      it 'sets a flash error' do
        spree_post :create, params
        expect(flash[:error]).to eq assigns(:widget).errors.full_messages.join(', ')
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

    context 'failure' do
      let(:params) do
        {
          id: widget.to_param,
          widget: {name: ''}, # a blank name will trigger a validation error
        }
      end

      it 'sets a flash error' do
        spree_put :update, params
        expect(flash[:error]).to eq assigns(:widget).errors.full_messages.join(', ')
      end
    end
  end

  describe '#update_positions' do
    let(:widget_1) { Widget.create!(name: 'widget 1', position: 1) }
    let(:widget_2) { Widget.create!(name: 'widget 2', position: 2) }

    subject { spree_post :update_positions, id: widget_1.to_param, positions: { widget_1.id => '2', widget_2.id => '1' }, format: 'js' }

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
