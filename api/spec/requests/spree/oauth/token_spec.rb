require 'spec_helper'

describe 'Spree OAuth', type: :request do
  let!(:user) { create(:user, email: 'new@user.com', password: 'secret', password_confirmation: 'secret') }

  describe 'get token' do
    shared_examples 'does not return a token' do
      it do
        expect(response.status).to eq(400)
        expect(json_response[:error]).to eq('invalid_grant')
      end
    end

    context 'by password' do
      context 'with confirmation' do
        before do
          module Spree
            module Auth
              class Config
                def self.[](key)
                  {
                    confirmable: true
                  }[key]
                end

                def self.[]=(key)
                end
              end
            end
          end

          allow(Spree.user_class).to receive(:find_for_database_authentication).with(hash_including(:email)) { user }
          allow(user).to receive(:valid_for_authentication?).and_return(true)
          allow(user).to receive(:active_for_authentication?).and_return(active_value)
          post '/spree_oauth/token?grant_type=password&username=new@user.com&password=secret'
        end

        context 'when the user is confirmed' do
          let(:active_value) { true }

          it 'returns new token' do
            expect(response.status).to eq(200)
            expect(json_response).to have_attributes([:access_token, :token_type, :expires_in, :refresh_token, :created_at])
            expect(json_response['token_type']).to eq('Bearer')
          end
        end

        context 'when the user is not confirmed' do
          let(:active_value) { false }

          it_behaves_like 'does not return a token'
        end
      end

      context 'user does not exist' do
        before do
          allow(Spree.user_class).to receive(:find_for_database_authentication).with(hash_including(:email)) { nil }
          post '/spree_oauth/token?grant_type=password&username=new@user.com&password=secret'
        end

        it_behaves_like 'does not return a token'
      end
    end
  end
end
