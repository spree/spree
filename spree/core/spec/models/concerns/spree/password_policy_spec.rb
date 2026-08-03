require 'spec_helper'

RSpec.describe Spree::PasswordPolicy do
  # Run the same battery against both hosts — behavior shared by Customer and
  # AdminUser must not drift on either. Preferences set here are reset between
  # examples by the global reset_spree_preferences before(:each) hook.
  shared_examples 'a password-policy host' do
    describe 'length floor' do
      it 'rejects a password shorter than the configured minimum' do
        record = build(factory, password: 'short12', password_confirmation: 'short12')

        expect(record).not_to be_valid
        expect(record.errors[:password]).to include('is too short (minimum is 8 characters)')
      end

      it 'accepts a password at the minimum length' do
        record = build(factory, password: 'exactly8', password_confirmation: 'exactly8')

        expect(record).to be_valid
      end

      it 'respects a raised minimum' do
        Spree::Config[:minimum_password_length] = 12
        record = build(factory, password: 'exactly8', password_confirmation: 'exactly8')

        expect(record).not_to be_valid
        expect(record.errors[:password]).to include('is too short (minimum is 12 characters)')
      end
    end

    describe 'length ceiling' do
      it 'rejects a password past the bcrypt limit' do
        too_long = 'a' * 73
        record = build(factory, password: too_long, password_confirmation: too_long)

        expect(record).not_to be_valid
        expect(record.errors[:password]).to include('is too long (maximum is 72 characters)')
      end
    end

    describe 'confirmation' do
      it 'rejects a mismatched confirmation' do
        record = build(factory, password: 'password123', password_confirmation: 'different123')

        expect(record).not_to be_valid
        expect(record.errors[:password_confirmation]).to be_present
      end
    end

    describe 'when no password is being set' do
      # The policy runs only while the digest is changing, so raising the floor
      # must never invalidate an already-persisted record.
      it 'leaves a persisted record valid after the minimum is raised' do
        record = create(factory, password: 'exactly8', password_confirmation: 'exactly8')
        Spree::Config[:minimum_password_length] = 30

        expect(record.reload).to be_valid
      end

      it 'allows saving an unrelated attribute after the minimum is raised' do
        record = create(factory, password: 'exactly8', password_confirmation: 'exactly8')
        Spree::Config[:minimum_password_length] = 30

        reloaded = record.reload
        reloaded.first_name = 'Changed'

        expect(reloaded.save).to be true
      end

      it 'still rejects a new short password under the raised floor' do
        record = create(factory, password: 'exactly8', password_confirmation: 'exactly8')
        Spree::Config[:minimum_password_length] = 30

        fresh = record.class.find(record.id)
        fresh.password = 'short12'
        fresh.password_confirmation = 'short12'

        expect(fresh).not_to be_valid
      end

      it 'allows a password-less record' do
        record = build(factory, password: nil, password_confirmation: nil)

        expect(record).to be_valid
      end
    end

    describe 'a swapped validator' do
      before { Spree.password_validator = SpreeSpec::NoDigitsValidator }

      after { Spree.password_validator = Spree::PasswordLengthValidator }

      it 'replaces the built-in length policy' do
        # 'short' is below the 8-char floor but passes the custom rule, proving
        # the default validator no longer runs.
        record = build(factory, password: 'short', password_confirmation: 'short')

        expect(record).to be_valid
      end

      it 'surfaces the custom failure reason on :password' do
        record = build(factory, password: 'has1digit', password_confirmation: 'has1digit')

        expect(record).not_to be_valid
        expect(record.errors[:password]).to include('must not contain digits')
      end
    end
  end

  context 'with Spree::Customer' do
    let(:factory) { :customer }

    it_behaves_like 'a password-policy host'
  end

  context 'with Spree::AdminUser' do
    let(:factory) { :admin_user }

    it_behaves_like 'a password-policy host'
  end
end
