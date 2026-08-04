# Support classes for Spree::PasswordPolicy specs — a stand-in for the custom
# password validator an integrator would assign to Spree.password_validator.
module SpreeSpec
  class NoDigitsValidator < ActiveModel::Validator
    def validate(record)
      return if record.password.blank?

      record.errors.add(:password, 'must not contain digits') if record.password.match?(/\d/)
    end
  end
end
