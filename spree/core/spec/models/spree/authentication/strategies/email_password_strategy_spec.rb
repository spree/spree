require 'spec_helper'

describe Spree::Authentication::Strategies::EmailPasswordStrategy do
  let(:user) { create(:user, email: 'user@example.com', password: 'password123') }
  let(:params) { { email: 'user@example.com', password: 'password123' } }
  let(:request_env) { {} }

  subject(:strategy) do
    described_class.new(params: params, request_env: request_env)
  end

  describe '#provider' do
    it 'returns email' do
      expect(strategy.provider).to eq('email')
    end
  end

  describe '#authenticate' do
    context 'with valid credentials' do
      before do
        user # ensure user exists
        # Stub password validation to isolate the strategy from the model's digest
        allow(user).to receive(:valid_password?).with('password123').and_return(true)
        allow(strategy).to receive(:find_user_by_email).with('user@example.com').and_return(user)
      end

      it 'returns successful result with user' do
        result = strategy.authenticate

        expect(result).to be_success
        expect(result.value).to eq(user)
      end
    end

    context 'with invalid email' do
      let(:params) { { email: 'nonexistent@example.com', password: 'password123' } }

      it 'returns failure result' do
        result = strategy.authenticate

        expect(result).not_to be_success
        expect(result.error).to eq('Invalid email or password')
      end
    end

    context 'with invalid password' do
      let(:params) { { email: 'user@example.com', password: 'wrongpassword' } }

      before do
        user # ensure user exists
        # Mock password validation to return false for wrong password
        allow(user).to receive(:valid_password?).with('wrongpassword').and_return(false)
        allow(strategy).to receive(:find_user_by_email).with('user@example.com').and_return(user)
      end

      it 'returns failure result' do
        result = strategy.authenticate

        expect(result).not_to be_success
        expect(result.error).to eq('Invalid email or password')
      end
    end

    describe 'account lockout' do
      before do
        allow(strategy).to receive(:find_user_by_email).with('user@example.com').and_return(user)
      end

      it 'fails a locked account without checking the password' do
        allow(user).to receive(:locked?).and_return(true)
        expect(strategy).not_to receive(:validate_password)

        result = strategy.authenticate

        expect(result).not_to be_success
        expect(result.error).to eq('Account temporarily locked. Try again later.')
      end

      it 'records a failed attempt on an invalid password' do
        allow(user).to receive(:valid_password?).with('password123').and_return(false)
        expect(user).to receive(:record_failed_attempt!)

        strategy.authenticate
      end

      it 'resets failed attempts on success when attempts were recorded' do
        allow(user).to receive(:valid_password?).with('password123').and_return(true)
        allow(user).to receive(:failed_attempts).and_return(3)
        expect(user).to receive(:reset_failed_attempts!)

        expect(strategy.authenticate).to be_success
      end

      it 'does not reset when there were no failed attempts' do
        allow(user).to receive(:valid_password?).with('password123').and_return(true)
        allow(user).to receive(:failed_attempts).and_return(0)
        expect(user).not_to receive(:reset_failed_attempts!)

        expect(strategy.authenticate).to be_success
      end

      it 'authenticates a user model that does not implement lockout' do
        bare_user = double('user without lockout', valid_password?: true)
        allow(strategy).to receive(:find_user_by_email).with('user@example.com').and_return(bare_user)

        result = strategy.authenticate

        expect(result).to be_success
        expect(result.value).to eq(bare_user)
      end
    end

    context 'when email is blank' do
      let(:params) { { email: '', password: 'password123' } }

      it 'returns failure result' do
        result = strategy.authenticate

        expect(result).not_to be_success
        expect(result.error).to eq('Email is required')
      end
    end

    context 'when email is missing' do
      let(:params) { { password: 'password123' } }

      it 'returns failure result' do
        result = strategy.authenticate

        expect(result).not_to be_success
        expect(result.error).to eq('Email is required')
      end
    end

    context 'when password is blank' do
      let(:params) { { email: 'user@example.com', password: '' } }

      it 'returns failure result' do
        result = strategy.authenticate

        expect(result).not_to be_success
        expect(result.error).to eq('Password is required')
      end
    end

    context 'when password is missing' do
      let(:params) { { email: 'user@example.com' } }

      it 'returns failure result' do
        result = strategy.authenticate

        expect(result).not_to be_success
        expect(result.error).to eq('Password is required')
      end
    end

    context 'when an error occurs' do
      before do
        allow(strategy).to receive(:find_user_by_email).and_raise(StandardError, 'Database error')
      end

      it 'logs the error and returns failure' do
        expect(Rails.logger).to receive(:error).with(/EmailPasswordStrategy authentication failed/)

        result = strategy.authenticate

        expect(result).not_to be_success
        expect(result.error).to eq('Authentication failed')
      end
    end
  end

  describe 'with custom user class' do
    let(:admin_user) { create(:admin_user, email: 'admin@example.com', password: 'admin123') }
    let(:params) { { email: 'admin@example.com', password: 'admin123' } }
    let(:user_class) { Spree.admin_user_class }

    subject(:strategy) do
      described_class.new(params: params, request_env: request_env, user_class: user_class)
    end

    it 'authenticates with admin user class' do
      admin_user # ensure admin user exists
      # Mock password validation for admin user
      allow(admin_user).to receive(:valid_password?).with('admin123').and_return(true)
      allow(strategy).to receive(:find_user_by_email).with('admin@example.com').and_return(admin_user)

      result = strategy.authenticate

      expect(result).to be_success
      expect(result.value).to eq(admin_user)
    end
  end
end
