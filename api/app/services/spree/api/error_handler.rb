module Spree
  module Api
    class ErrorHandler
      prepend ::Spree::ServiceModule::Base

      def call(exception:)
        run :format_message
        run :log_error
        run :report_error
      end

      protected

      def format_message(exception:)
        message = if exception.respond_to?(:original_message)
                    exception.original_message
                  else
                    exception.message
                  end

        success(exception: exception, message: message)
      end

      def log_error(exception:, message:)
        Rails.logger.error message
        Rails.logger.error exception.backtrace.join("\n")

        success(exception: exception, message: message)
      end

      def report_error(exception:, message:)
        # overwrite this method in your application to support different error handlers
        # eg. Sentry, Rollbar, etc

        success(exception: exception, message: message)
      end
    end
  end
end
