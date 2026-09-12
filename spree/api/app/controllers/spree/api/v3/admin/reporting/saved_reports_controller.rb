module Spree
  module Api
    module V3
      module Admin
        module Reporting
          # Store-wide saved reports (docs/plans/6.0-analytics-semantic-layer.md,
          # Decision 12). Reads ride `read_reports`, mutations `write_reports`;
          # the stored query is validated against the registry on save, and
          # every viewer is re-authorized when the report is executed through
          # the query endpoint.
          class SavedReportsController < ResourceController
            scoped_resource :reports

            protected

            def model_class
              Spree::SavedReport
            end

            def serializer_class
              Spree.api.admin_saved_report_serializer
            end

            def scope_includes
              [:user]
            end

            # Deliberately NOT routed through `normalize_params`: the stored
            # query carries filter values such as `cust_…`/`ch_…` prefixed ids
            # inside a nested hash, and prefixed-ID resolution recurses into
            # nested hashes — they would be decoded to integers on save and
            # never resolve again. Extension attributes are splatted in.
            def permitted_params
              params.permit(:name, :description, *model_additional_permitted_attributes, query: {})
            end

            def build_resource
              super.tap { |report| report.user = try_spree_current_user }
            end
          end
        end
      end
    end
  end
end
