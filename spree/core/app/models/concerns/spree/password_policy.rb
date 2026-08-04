module Spree
  # Password policy for the default auth models (Customer, AdminUser).
  #
  # The policy itself lives in {Spree.password_validator} — by default
  # {Spree::PasswordLengthValidator}. Swap that to replace it wholesale.
  #
  # Validation runs only while a password is actually being set, so raising the
  # floor on an existing install invalidates no stored digest — short legacy
  # passwords keep working until their owner next changes them.
  module PasswordPolicy
    extend ActiveSupport::Concern

    included do
      validates :password, confirmation: true, allow_blank: true

      # Resolved per call rather than at include time so an integrator can swap
      # the validator after the models have loaded, and so a development reload
      # picks up changes to it.
      validate :validate_password_policy, if: :password_policy_applicable?
    end

    private

    # Only vet a password that is actually being set. +has_secure_password+ leaves
    # the virtual +password+ populated in memory after a save, so testing it alone
    # would re-validate an untouched record — and raising the floor on a live
    # install would then break saves for every existing user whose password is
    # shorter than the new minimum.
    def password_policy_applicable?
      password.present? && password_digest_changed?
    end

    def validate_password_policy
      Spree.password_validator.new(attributes: [:password]).validate(self)
    end
  end
end
