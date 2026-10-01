module Spree
  module Api
    module V3
      module Admin
        module EmailTemplates
          # The published versions of an email template in one language, newest
          # first. Reverting keeps them, so they outlive the published version.
          class RevisionsController < ResourceController
            include Spree::Api::V3::Admin::EmailTemplateLookup

            protected

            def model_class
              Spree::EmailTemplateRevision
            end

            def serializer_class
              Spree.api.admin_email_template_revision_serializer
            end

            def scope
              email_template_revisions.order(created_at: :desc)
            end

            def collection_includes
              [:published_by]
            end
          end
        end
      end
    end
  end
end
