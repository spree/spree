module Spree
  # Stores a model's `:password` preferences in a separate `secret_preferences`
  # text column, encrypted with Active Record encryption whenever keys are
  # configured, so the `preferences` column never holds a secret. Declarations
  # are unchanged: `preference :secret_key, :password` and
  # `preferred_secret_key` read and write the encrypted column.
  #
  # Values written before encryption was enabled stay readable and are
  # encrypted on the next save, or at once by
  # `spree:upgrade:encrypt_secret_preferences`.
  module SecretPreferences
    extend ActiveSupport::Concern

    included do
      serialize :secret_preferences, coder: TextHashSerializer

      if ActiveRecord::Encryption.config.has_primary_key?
        encrypts :secret_preferences, support_unencrypted_data: true
      end

      before_save :move_secret_preferences
    end

    # The column is `text`, since ciphertext cannot live in a JSON column. An
    # empty column stays nil rather than `{}`: encrypted attributes compare the
    # stored value with the loaded one, so `{}` would mark every record without
    # secrets as changed.
    class TextHashSerializer
      def self.dump(hash)
        ActiveSupport::JSON.encode(hash) unless hash.nil?
      end

      def self.load(json)
        Spree::Metadata::HashSerializer.load(ActiveSupport::JSON.decode(json)) unless json.nil?
      end
    end

    # Both columns as they should be stored, when `preferences` holds a secret
    # — one assigned as part of a whole hash, or one the upgrade has not moved
    # yet. A secret found there is the newer value and wins.
    #
    # @return [Hash{Symbol => Hash}, nil] `preferences:` and `secret_preferences:`, or nil when there is nothing to move
    def separated_secret_preferences
      secrets = (preferences || {}).slice(*self.class.secret_preference_names)
      return if secrets.empty?

      { preferences: preferences.except(*secrets.keys), secret_preferences: (secret_preferences || {}).merge(secrets) }
    end

    private

    # Keeps a secret out of the plain `preferences` column when the record is
    # saved.
    def move_secret_preferences
      separated = separated_secret_preferences
      assign_attributes(separated) if separated
    end
  end
end
