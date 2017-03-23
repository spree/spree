require 'spec_helper'

describe EmailValidator do

  class Tester
    include ActiveModel::Validations
    attr_accessor :email_address
    validates :email_address, email: true
  end

  class TesterWithMx
    include ActiveModel::Validations
    attr_accessor :email_address
    validates :email_address, email: { check_mx: true }
  end

  let(:valid_emails) {[
    'valid@email.com',
    'valid@email.com.uk',
    'e@email.com',
    'valid+email@email.com',
    'valid-email@email.com',
    'valid_email@email.com',
    'validemail_@email.com',
    'valid.email@email.com',
    'valid.email@email.photography',
    'user@email.gov.in',
    'user@[127.0.0.1]',
    'disposable.style.email.with+symbol@example.com',
    '"very.unusual.@.unusual.com"@example.com',
    'example-indeed@strange-example.com',
    'admin@mailserver1',
    "#!$%&'*+-/=?^_`{}|~@example.org",
    '" "@example.org',
    'just."not".right@example.com'
  ]}

  let(:invalid_emails) {[
    '',
    ' ',
    'invalid email@email.com',
    'invalidemail @email.com',
    'invalidemail@email..com',
    '.invalid.email@email.com',
    'invalid.email.@email.com',
    '@email.com',
    '.@email.com',
    'invalidemailemail.com',
    '@invalid.email@email.com',
    'invalid@email@email.com',
    'invalid.email@@email.com',
    'invalid.email@@email-.com',
    '"very.unusual.@.unusual.com@example.com',
    'a"b(c)d,e:f;g<h>i[j\k]l@example.com',
    'just"not"right@example.com',
    'just"not"right@exampleexampleexampleexampleexampleexampleexampleexampleexample.com'
  ]}

  it 'validates valid email addresses' do
    tester = Tester.new
    valid_emails.each do |email|
      tester.email_address = email
      expect(tester.valid?).to be true
    end
  end

  it 'validates invalid email addresses' do
    tester = Tester.new
    invalid_emails.each do |email|
      tester.email_address = email
      expect(tester.valid?).to be false
    end
  end

  it 'validates valid email addresses with resolve dns' do
    tester = TesterWithMx.new
    tester.email_address = 'test@gmail.com'
    expect(tester.valid?).to be true
  end

  it 'validates invalid email addresses with resolve dns' do
    tester = TesterWithMx.new
    tester.email_address = 'test@invalidedomain.com'
    expect(tester.valid?).to be false
  end
end
