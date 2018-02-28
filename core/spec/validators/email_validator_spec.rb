require 'spec_helper'

describe EmailValidator do
  class Tester
    include ActiveModel::Validations
    attr_accessor :email_address
    validates :email_address, email: true
  end

  let(:valid_emails) do
    [
      'valid@email.com',
      'valid@email.com.uk',
      'e@email.com',
      'valid+email@email.com',
      'valid-email@email.com',
      'valid_email@email.com',
      'validemail_@email.com',
      'valid.email@email.com',
      'valid.email@email.photography'
    ]
  end
  let(:invalid_emails) do
    [
      '',
      ' ',
      'invalid email@email.com',
      'invalidemail @email.com',
      '@email.com',
      'invalidemailemail.com',
      '@invalid.email@email.com',
      'invalid@email@email.com',
      'invalid.email@@email.com'
    ]
  end

  let(:tester) { Tester.new }

  it 'validates valid email addresses' do
    valid_emails.each do |email|
      tester.email_address = email
      expect(tester).to be_valid
    end
  end

  it 'validates invalid email addresses' do
    invalid_emails.each do |email|
      tester.email_address = email
      expect(tester).to be_invalid
    end
  end
end
