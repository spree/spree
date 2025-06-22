require 'spec_helper'

describe Spree::Admin::ProfileController, type: :controller do
  stub_authorization!

  describe '#edit' do
    subject { get :edit }

    it 'renders the edit template' do
      expect(subject).to render_template(:edit)
    end
  end

  describe '#update' do
    subject { put :update, params: params }

    let(:params) do
      { user: { first_name: 'John', last_name: 'Doe' } }
    end

    it 'updates the user' do
      expect { subject }.to change { admin_user.first_name }.to('John')
    end
  end
end
