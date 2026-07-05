module Spree
  class ReportMailer < BaseMailer
    def report_done(report)
      @report = report

      mail(
        to: @report.user.email,
        subject: Spree.t('report_mailer.report_done.subject', report_name: @report.human_name).to_s,
        from: from_address,
        reply_to: reply_to_address
      )
    end

    private

    def current_store
      @current_store ||= @report.store
    end
  end
end
