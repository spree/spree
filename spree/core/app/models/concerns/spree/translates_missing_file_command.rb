# frozen_string_literal: true

module Spree
  # Spoofing-protected uploads ask the Unix `file` command what the bytes
  # really are. When that command is missing the validation library raises
  # its own install text, and a naive rescue (or an unrescued raise) shows
  # that text to the buyer. This concern turns the raise into a validation
  # error they can act on — try a PDF, image or Word file — and leaves the
  # install instruction in the log for the operator.
  #
  # The starter image must install `file` in its runtime stage. This concern
  # is the fallback so a stock host that has not yet done so never leaks
  # the library message through the Store API, the Admin API, or the seller
  # panel.
  module TranslatesMissingFileCommand
    extend ActiveSupport::Concern

    FILE_COMMAND_MISSING = ActiveStorageValidations::Analyzer::ContentTypeAnalyzer::FileCommandLineToolNotInstalledError

    included do
      around_validation :translate_missing_file_command
    end

    private

    def translate_missing_file_command
      yield
    rescue FILE_COMMAND_MISSING => error
      Rails.logger.error(
        "[spree] #{error.message}. Document uploads need the Unix file command " \
        '(apt-get install -y file).'
      )
      errors.add(:base, Spree.t(:attachment_could_not_be_verified))
    end
  end
end
