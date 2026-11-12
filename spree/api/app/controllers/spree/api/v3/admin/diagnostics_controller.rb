module Spree
  module Api
    module V3
      module Admin
        # The anonymised diagnostics report (Spree::Diagnostics) for bug
        # reports. It reveals the running version and stack, so it answers
        # signed-in staff who can manage the store and nobody else, like
        # GET /updates: a secret API key gets a 404, a connected app a 403.
        class DiagnosticsController < Admin::BaseController
          skip_scope_check!

          before_action :require_staff_session!

          # Only a published @spree/* name and a version: anything else in
          # the list is dropped rather than echoed into a public report.
          PACKAGE = %r{\A(@spree/[a-z0-9-]{1,50})@(\d+\.\d+\.\d+[0-9A-Za-z.-]{0,20})\z}
          PACKAGE_LIMIT = 20

          # GET /api/v3/admin/diagnostics
          def show
            authorize! :manage, current_store

            report = Spree::Diagnostics.report(store: current_store, extra_sections: dashboard_section + client_section)
            render json: Spree.api.admin_diagnostics_serializer.new(report).to_h
          end

          private

          # The caller's @spree/* packages, which the server can't see: the
          # dashboard may be built and deployed apart from it.
          def dashboard_section
            rows = params[:packages].to_s.split(',').first(PACKAGE_LIMIT).filter_map { |package| PACKAGE.match(package)&.captures }
            rows.any? ? [{ title: 'Dashboard', rows: rows.to_h }] : []
          end

          # The browser the report was opened in, which only this request knows.
          def client_section
            return [] if request.user_agent.blank?

            [{ title: 'Client', rows: { 'User agent' => request.user_agent } }]
          end
        end
      end
    end
  end
end
