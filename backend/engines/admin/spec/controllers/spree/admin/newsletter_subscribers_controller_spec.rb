require 'spec_helper'

RSpec.describe Spree::Admin::NewsletterSubscribersController, type: :controller do
  stub_authorization!
  render_views

  describe '#index' do
    let!(:newsletter_subscribers) { create_list(:newsletter_subscriber, 3) }

    it 'renders the index template' do
      get :index
      expect(response).to render_template(:index)
      expect(response.status).to eq(200)
      expect(assigns(:collection).to_a).to eq(newsletter_subscribers)
    end
  end

  describe '#destroy' do
    let!(:newsletter_subscriber) { Spree::NewsletterSubscriber.create!(email: 'test@example.com') }

    it 'destroys the newsletter subscriber and redirects' do
      expect {
        delete :destroy, params: { id: newsletter_subscriber.to_param }
      }.to change(Spree::NewsletterSubscriber, :count).by(-1)
      expect(response).to redirect_to(admin_newsletter_subscribers_path)
    end
  end
end
