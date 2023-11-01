##
# Validates a field based on the maximum length of the underlying DB field, if there is one.
class DbMaximumLengthValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    Spree::Deprecation.warn(<<-DEPRECATION, caller)
      `DbMaximumLengthValidator` is deprecated and will be removed in Spree 5.0.
      Please remove any `db_maximum_length: true` validations from your codebase
    DEPRECATION

    limit = record.class.columns_hash[attribute.to_s].limit
    value = record[attribute.to_sym]
    if value && limit && value.to_s.length > limit
      record.errors.add(attribute.to_sym, :too_long, count: limit)
    end
  end
end
