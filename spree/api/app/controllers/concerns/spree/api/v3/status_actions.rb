module Spree
  module Api
    module V3
      # Moving a record between statuses through a workflow.
      #
      # Every such action has the same shape: find the record, check the write
      # key, run the workflow, and answer with the reloaded record or with
      # whatever refused it. The refusal path is the subtle half — a workflow
      # that rejected before touching the record leaves `errors` empty, so the
      # result's own error is the fallback — and it was copied into four
      # controllers before this existed.
      #
      # The workflow's keyword is derived from `model_class`, so a controller
      # only has to name the workflow.
      module StatusActions
        extend ActiveSupport::Concern

        protected

        # Finds the record a status action addresses and authorizes the write.
        #
        # Named apart from the base class's own lookup because overriding that
        # one would change every action, while only the status actions need
        # this. A status move is a change to the record, so it answers to the
        # write key rather than one of its own — a read-only role cannot
        # submit, take down or archive.
        #
        # @return [void]
        def set_status_resource
          @resource = find_resource
          authorize!(:update, @resource)
        end

        # @param workflow [#call]
        # @param arguments [Hash] passed through to the workflow
        # @return [void]
        def run_status_workflow(workflow, **arguments)
          result = workflow.call(status_workflow_keyword => @resource, **arguments)

          if result.success?
            render json: serialize_resource(@resource.reload)
          else
            render_service_error(@resource.errors.presence || result.error)
          end
        end

        # What the workflow calls its subject — `product:` for
        # `Spree::Product`, `variant:` for `Spree::Variant`.
        #
        # @return [Symbol]
        def status_workflow_keyword
          model_class.model_name.singular.delete_prefix('spree_').to_sym
        end

        # A review status is an outcome, not a value to assign: `proposed`
        # means somebody asked, and `rejected` means somebody decided. Both are
        # reached through the review workflows, which record who decided and
        # settle the submission row — writing one straight onto a record would
        # leave a seller looking at a decision nobody made.
        #
        # @param status [String, nil]
        # @return [Boolean]
        def review_status?(status)
          status.present? && model_class::REVIEW_STATUSES.include?(status.to_s)
        end
      end
    end
  end
end
