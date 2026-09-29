module Spree
  module Emails
    class ExportSerializer < BaseSerializer
      attributes :number, :results_url

      attribute :filename do |export|
        export.attachment.filename.to_s if export.attachment.attached?
      end

      one :user, resource: Spree::Emails::UserSerializer
    end
  end
end
