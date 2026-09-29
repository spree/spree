namespace :spree do
  namespace :emails do
    desc 'Writes the email template variable reference (PATH defaults to the monorepo docs page)'
    task variable_reference: :environment do
      require 'spree/emails/variable_reference'

      path = ENV.fetch('PATH_TO_REFERENCE') { Spree::Emails::Engine.root.join('../../docs/developer/customization/email-variables.mdx').to_s }
      File.write(path, Spree::Emails::VariableReference.call)
      puts "Wrote #{path}"
    end
  end
end
