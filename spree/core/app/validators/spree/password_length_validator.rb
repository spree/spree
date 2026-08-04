module Spree
  # Default password policy: a length floor with no composition rules, following
  # NIST 800-63B (forced symbols and digits push people toward predictable
  # substitutions). Bounds are configurable via
  # +Spree::Config[:minimum_password_length]+ and +[:maximum_password_length]+.
  #
  # Replace the whole policy with {Spree.password_validator=}.
  class PasswordLengthValidator < ActiveModel::Validator
    def validate(record)
      password = record.password
      return if password.blank?

      minimum = Spree::Config[:minimum_password_length]
      maximum = Spree::Config[:maximum_password_length]

      if password.length < minimum
        record.errors.add(:password, :too_short, count: minimum)
      elsif password.length > maximum
        record.errors.add(:password, :too_long, count: maximum)
      end
    end
  end
end
