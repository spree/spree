##
# Validates a field based on the maximum length of the underlying DB field, if there is one.
class DbMaximumLengthValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    limit = record.class.columns_hash[attribute.to_s].limit
    value = record[attribute.to_sym]
    if value && limit && value.to_s.length > limit
      record.errors.add(attribute.to_sym, :too_long, count: limit)
    end
  end
end
