require 'rails_helper'

RSpec.describe Spree::ContactsController, type: :controller do
  let(:store) { Spree::Store.default }
  let(:contact_params) { { name: "John Doe", email: "john@example.com", message: "Test message" } }

  context 'when customer support email is not configured' do
    it 'redirects to root path' do
      get :new
      expect(response).to redirect_to(root_path)
    end
  end

  context 'when customer support email is configured' do
    before do
      store.update(customer_support_email: 'test@example.com')
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

    describe "#validate_captcha" do
      context "when recaptcha integration is present" do
        let!(:recaptcha_integration) { create(:recaptcha_integration) }

        it "verifies recaptcha" do
          expect(controller).to receive(:verify_recaptcha).and_return(true)
          post :create, params: { contact: contact_params }
        end

        context "when recaptcha verification fails" do
          before do
            allow(controller).to receive(:verify_recaptcha).and_return(false)
          end

          it "sets an error flash message" do
            post :create, params: { contact: contact_params }
            expect(flash[:error]).to eq('Captcha verification failed, please try again.')
          end

          it "redirects to new action" do
            post :create, params: { contact: contact_params }
            expect(response).to redirect_to(action: :new)
          end
        end
      end
    end
  end
end
