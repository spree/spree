require 'rails/generators'
require 'spree/core'

module Spree
  module Emails
    module Generators
      class InstallGenerator < Rails::Generators::Base
        desc 'Installs mailers previews for Spree transactional emails'

        def self.source_paths
          [
            File.expand_path('templates', __dir__)
          ]
        end

        def copy_mailers_previews
          preview_path = Rails.application&.config&.action_mailer&.preview_path.presence || 'test/mailers/previews'

          template 'mailers/previews/order_preview.rb', "#{preview_path}/order_preview.rb"
          template 'mailers/previews/shipment_preview.rb', "#{preview_path}/shipment_preview.rb"
          template 'mailers/previews/reimbursement_preview.rb', "#{preview_path}/reimbursement_preview.rb"
          template 'mailers/previews/user_preview.rb', "#{preview_path}/user_preview.rb"
        end
      end
    end
  end
end
