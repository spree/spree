# Shared behavior for models that include Spree::AccountLockout.
# The including example group must define `let(:lockable)` returning a persisted
# record of such a model. Preferences set here are reset between examples by the
# global reset_spree_preferences before(:each) hook.
RSpec.shared_examples 'account lockout' do
  describe 'account lockout' do
    it 'is not locked by default' do
      expect(lockable).not_to be_locked
    end

    it 'locks after the configured number of failed attempts' do
      Spree::Config[:max_failed_login_attempts] = 2

      lockable.record_failed_attempt!
      expect(lockable).not_to be_locked

      lockable.record_failed_attempt!
      expect(lockable.reload).to be_locked
    end

    it 'still locks when a stale instance records the threshold attempt' do
      Spree::Config[:max_failed_login_attempts] = 2
      # A second handle on the same row, loaded while the counter is 0 — the row
      # lock must make its increment read the latest value rather than overwrite it.
      stale = lockable.class.find(lockable.id)

      lockable.record_failed_attempt!
      stale.record_failed_attempt!

      expect(lockable.reload).to be_locked
      expect(lockable.failed_attempts).to eq(2)
    end

    it 'clears the lock and counter on reset' do
      Spree::Config[:max_failed_login_attempts] = 2
      2.times { lockable.record_failed_attempt! }

      lockable.reset_failed_attempts!

      expect(lockable.reload).not_to be_locked
      expect(lockable.failed_attempts).to eq(0)
    end

    it 'unlocks once the lockout_duration window has passed' do
      Spree::Config[:max_failed_login_attempts] = 1
      Spree::Config[:lockout_duration] = 15.minutes.to_i
      lockable.record_failed_attempt!
      expect(lockable).to be_locked

      lockable.update_column(:locked_at, 16.minutes.ago)
      expect(lockable).not_to be_locked
    end
  end
end
