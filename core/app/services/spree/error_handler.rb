module Spree
  class ErrorHandler
    prepend ::Spree::ServiceModule::Base

    # Handles errors and logs them to the console.
    #
    # @param exception [Exception]
    # @param opts [Hash]
    # @option opts [Hash] :report_context
    # @option opts [User] :user
    def call(exception:, opts: {})
      run :format_message
      run :log_error
      run :report_error
    end

    protected

    def format_message(exception:, opts: {})
      message = if exception.respond_to?(:original_message)
                  exception.original_message
                else
                  exception.message
                end

      success(exception: exception, message: message, opts: opts)
    end

    def log_error(exception:, message:, opts: {})
      Rails.logger.error message
      Rails.logger.error "User ID: #{opts[:user]&.id}" if opts[:user]
      Rails.logger.error exception.backtrace.join("\n") if exception.backtrace.present?

      success(exception: exception, message: message, opts: opts)
    end

    def report_error(exception:, message:, opts: {})
      # overwrite this method in your application to support different error handlers
      # eg. Sentry, Rollbar, etc
      if defined?(Sentry)
        if opts[:report_context].present?
          Sentry.configure_scope do |scope|
            scope.set_context(:extra, opts[:report_context])
          end
        end

        Sentry.capture_exception(exception)
      end

      success(exception: exception, message: message)
    end
  end
end
