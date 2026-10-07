module Spree
  module Api
    module V3
      module Admin
        module EmailTemplates
          class SampleRecordsController < Admin::BaseController
            include Spree::Api::V3::Admin::EmailTemplateLookup

            before_action :authorize_sample_data!

            # GET /api/v3/admin/email_templates/:email_template_id/sample_records
            #
            # The store's five latest records the template can be previewed
            # with (for the layout and partials, those of the email `email_key`
            # names). Empty for an email that needs no record.
            def index
              authorize! :update, Spree::EmailTemplate

              records = build_preview.email.sample_class.new(store: current_store).recent_records
              render json: { data: records.map { |record| serializer_class.new(record, params: serializer_params).to_h } }
            end

            private

            def serializer_class
              Spree.api.admin_email_template_sample_record_serializer
            end
          end
        end
      end
    end
  end
end
