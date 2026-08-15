module Spree
  module Api
    module V3
      module Admin
        # Admin API serializer for {Spree::MaintenanceTaskRun} — the progress
        # the dashboard polls while a task runs, and the audit trail it shows
        # afterwards (docs/plans/6.0-maintenance-tasks.md).
        #
        # Admin-only by design: there is no store counterpart, because nothing
        # about operator-run data work is customer-facing.
        class MaintenanceTaskRunSerializer < BaseSerializer
          typelize task_name: :string,
                   status: :string,
                   dry_run: :boolean,
                   initiated_via: :string,
                   cursor: [:string, nullable: true],
                   tick_count: :number,
                   tick_total: [:number, nullable: true],
                   progress: [:number, nullable: true],
                   duration: [:number, nullable: true],
                   tallies: 'Record<string, number>',
                   arguments: 'Record<string, unknown>',
                   error_class: [:string, nullable: true],
                   error_message: [:string, nullable: true],
                   error_backtrace: [:string, nullable: true],
                   resumable: :boolean,
                   cancelable: :boolean,
                   active: :boolean,
                   store_id: [:string, nullable: true],
                   parent_run_id: [:string, nullable: true],
                   started_at: [:string, nullable: true],
                   ended_at: [:string, nullable: true],
                   admin_user: '{ id: string; email: string; first_name: string | null; last_name: string | null } | null'

          attributes :task_name, :status, :dry_run, :initiated_via, :cursor,
                     :tick_count, :tick_total, :error_class, :error_message,
                     :started_at, :ended_at, :created_at, :updated_at

          attribute :progress, &:progress

          attribute :duration do |run|
            run.duration&.round(3)
          end

          attribute :tallies do |run|
            run.tallies || {}
          end

          # Never the raw values: a task may take a token or a customer
          # identifier as a parameter.
          attribute :arguments, &:display_arguments

          # The failure detail an operator needs to fix the cause. Held back
          # from read-only callers — a backtrace names internal paths and
          # class names that a read scope has no business seeing.
          attribute :error_backtrace do |run|
            run.error_backtrace if params[:show_backtrace]
          end

          attribute :resumable, &:resumable?
          attribute :cancelable, &:cancelable?
          attribute :active, &:active?

          attribute :store_id do |run|
            run.store&.prefixed_id
          end

          attribute :parent_run_id do |run|
            run.parent_run&.prefixed_id
          end

          # Who fired it. Embedded rather than referenced: a run list is read
          # to answer "who ran what", and a second request per row for a name
          # would make that the slowest page in the dashboard.
          attribute :admin_user do |run|
            next nil if run.admin_user.nil?

            {
              id: run.admin_user.prefixed_id,
              email: run.admin_user.email,
              first_name: run.admin_user.first_name,
              last_name: run.admin_user.last_name
            }
          end
        end
      end
    end
  end
end
