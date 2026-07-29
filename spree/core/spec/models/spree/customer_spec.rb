require 'spec_helper'

describe Spree::Customer, type: :model do
  subject(:customer) { create(:customer, password: 'secret-123', password_confirmation: 'secret-123') }

  describe 'has_secure_password' do
    it 'authenticates with the correct password' do
      expect(customer.authenticate('secret-123')).to eq(customer)
    end

    it 'rejects an incorrect password' do
      expect(customer.authenticate('wrong')).to be(false)
    end

    it 'exposes valid_password? as an alias for authenticate' do
      expect(customer.valid_password?('secret-123')).to be(true)
      expect(customer.valid_password?('wrong')).to be(false)
    end

    it 'allows a customer without a password (admin-created, claim later)' do
      expect(build(:customer, password: nil, password_confirmation: nil)).to be_valid
    end
  end

  describe 'validations' do
    it 'requires an email' do
      expect(build(:customer, email: nil)).not_to be_valid
    end

    it 'enforces case-insensitive email uniqueness' do
      customer
      dup = build(:customer, email: customer.email.upcase)
      expect(dup).not_to be_valid
    end
  end

  describe 'password reset tokens' do
    it 'round-trips through find_by_password_reset_token' do
      token = customer.generate_token_for(:password_reset)
      expect(described_class.find_by_password_reset_token(token)).to eq(customer)
    end

    it 'invalidates the token when the password changes' do
      token = customer.generate_token_for(:password_reset)
      customer.update!(password: 'new-secret-123', password_confirmation: 'new-secret-123')
      expect(described_class.find_by_password_reset_token(token)).to be_nil
    end
  end

  describe 'account lockout' do
    it 'is not locked by default' do
      expect(customer).not_to be_locked
    end

    it 'locks after five failed attempts' do
      5.times { customer.record_failed_attempt! }
      expect(customer).to be_locked
    end

    it 'clears the lock on reset' do
      5.times { customer.record_failed_attempt! }
      customer.reset_failed_attempts!
      expect(customer.reload).not_to be_locked
      expect(customer.failed_attempts).to eq(0)
    end
  end

  describe 'prefixed id' do
    it 'uses the cust_ prefix' do
      expect(customer.prefixed_id).to start_with('cust_')
    end
  end
end
