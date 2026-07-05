class EmailValidator < ActiveModel::EachValidator
  EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i

  def validate_each(record, attribute, value)
    unless value =~ EMAIL_REGEX
      record.errors.add(attribute, :invalid, **{ value: value }.merge!(options))
    end
  end
end
