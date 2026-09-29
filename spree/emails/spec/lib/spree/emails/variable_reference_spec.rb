require 'spec_helper'
require 'spree/emails/variable_reference'

describe Spree::Emails::VariableReference do
  let(:published) { Spree::Emails::Engine.root.join('../../docs/developer/customization/email-variables.mdx') }

  it 'lists a template for every email Spree ships' do
    shipped = Dir[Spree::Emails::Engine.root.join('app/views/spree/*_mailer/*.liquid'),
                  Spree::Core::Engine.root.join('app/views/spree/*_mailer/*.liquid')].
              map { |path| path[%r{spree/\w+_mailer/\w+(?=\.liquid)}] }

    expect(described_class::EMAILS.keys).to match_array(shipped)
  end

  it 'matches the published reference' do
    skip 'outside the monorepo' unless published.exist?

    expect(described_class.call).to eq(published.read),
      'The email variable reference is out of date: run `bin/rails spree:emails:variable_reference` in spree/emails/spec/dummy'
  end
end
