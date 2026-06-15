require 'spec_helper'

RSpec.describe Spree::Admin::AuthRateLimiting, type: :controller do
  # Counters live in Rails.cache, which is :null_store in the test env.
  # Replace increment with a real in-memory counter so the rate limit trips.
  let(:counts) { Hash.new(0) }

  before do
    allow(Rails.cache).to receive(:increment) { |key, amount = 1, **_opts| counts[key] += amount }
  end

  it 'includes the AuthRateLimiting concern in devise controllers' do
    expect(Spree::Admin::UserSessionsController.include?(described_class)).to be(true)
    expect(Spree::Admin::UserPasswordsController.include?(described_class)).to be(true)
  end

  describe 'login rate limit' do
    controller(ActionController::Base) do
      include Spree::Admin::AuthRateLimiting

      auth_rate_limit :rate_limit_login, redirect_to: -> { new_session_path(resource_name) }

      def create
        head :ok
      end

      private

      # Minimal Devise stand-ins used by the concern.
      def resource_name
        :admin_user
      end

      def resource_params
        params.fetch(:admin_user, {})
      end

      def new_session_path(_resource)
        '/admin_user/sign_in'
      end

      def new_password_path(_resource)
        '/admin_user/password'
      end
    end

    let(:limit) { Spree::Admin::RuntimeConfig[:rate_limit_login] }

    before { routes.draw { post 'create' => 'anonymous#create' } }

    def attempt(email: nil, ip: '203.0.113.1')
      request.remote_addr = ip
      post :create, params: { admin_user: { email: email } }
    end

    it 'allows attempts up to the per-IP limit, then rate limits the next one' do
      limit.times { attempt(ip: '203.0.113.7') }
      expect(response).to have_http_status(:ok)

      attempt(ip: '203.0.113.7')
      expect(response).to redirect_to('/admin_user/sign_in')
      expect(flash[:alert]).to eq(I18n.t('devise.failure.too_many_attempts'))
    end

    it 'rate limits a single account across rotating IPs (per-email bucket)' do
      limit.times { |i| attempt(email: 'victim@example.com', ip: "198.51.100.#{i}") }
      expect(response).to have_http_status(:ok)

      attempt(email: 'victim@example.com', ip: '198.51.100.250')
      expect(response).to redirect_to('/admin_user/sign_in')
    end

    it 'normalizes email case (Foo@X.com and foo@x.com share a bucket)' do
      limit.times { |i| attempt(email: (i.even? ? 'Victim@X.com' : 'victim@x.com'), ip: "198.51.100.#{i}") }
      attempt(email: 'VICTIM@x.com', ip: '198.51.100.250')
      expect(response).to redirect_to('/admin_user/sign_in')
    end

    it 'does not globally lock out blank-email attempts from different IPs' do
      (limit + 5).times { |i| attempt(email: '', ip: "10.0.0.#{i}") }
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'password-reset rate limit' do
    controller(ActionController::Base) do
      include Spree::Admin::AuthRateLimiting

      auth_rate_limit :rate_limit_password_reset, redirect_to: -> { new_password_path(resource_name) }

      def create
        head :ok
      end

      private

      def resource_name
        :admin_user
      end

      def resource_params
        params.fetch(:admin_user, {})
      end

      def new_session_path(_resource)
        '/admin_user/sign_in'
      end

      def new_password_path(_resource)
        '/admin_user/password'
      end
    end

    let(:limit) { Spree::Admin::RuntimeConfig[:rate_limit_password_reset] }

    before { routes.draw { post 'create' => 'anonymous#create' } }

    def attempt(ip:)
      request.remote_addr = ip
      post :create, params: { admin_user: { email: 'victim@example.com' } }
    end

    it 'rate limits past the password-reset limit and redirects to the password page' do
      limit.times { |i| attempt(ip: "198.51.100.#{i}") }
      expect(response).to have_http_status(:ok)

      attempt(ip: '198.51.100.250')
      expect(response).to redirect_to('/admin_user/password')
      expect(flash[:alert]).to eq(I18n.t('devise.failure.too_many_attempts'))
    end
  end
end
