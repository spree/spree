require 'spec_helper'

RSpec.describe Spree::ContactsController, type: :controller do
  let(:store) { @default_store }
  let(:contact_params) { { name: "John Doe", email: "john@example.com", message: "Test message" } }

  render_views

  before do
    allow(controller).to receive(:current_store).and_return(store)
  end

  context 'when customer support email is not configured' do
    before do
      allow_any_instance_of(Spree::Store).to receive(:customer_support_email).and_return(nil)
    end

    it 'redirects to root path' do
      get :new
      expect(response).to redirect_to(root_path)
    end
  end

  context 'when customer support email is configured' do
    before do
      allow_any_instance_of(Spree::Store).to receive(:customer_support_email).and_return('test@example.com')
    end

    describe "POST #create" do
      context "when contact is delivered successfully" do
        before do
          allow_any_instance_of(Spree::Contact).to receive(:deliver).and_return(true)
        end

        it "sets a success flash message" do
          post :create, params: { contact: contact_params }
          expect(flash[:success]).to eq('Message sent!')
        end

        it "redirects to new action" do
          post :create, params: { contact: contact_params }
          expect(response).to redirect_to(action: :new)
        end
      end

      context "when contact delivery fails" do
        before do
          allow_any_instance_of(Spree::Contact).to receive(:deliver).and_return(false)
        end

        it "sets an error flash message" do
          post :create, params: { contact: contact_params }
          expect(flash[:error]).to eq("Unfortunately we weren't able to send the email at this time. Please try again later")
        end

        it "redirects to new action" do
          post :create, params: { contact: contact_params }
          expect(response).to redirect_to(action: :new)
        end
      end
    end
  end
end
