# frozen_string_literal: true

module Spree
  module PagyHelper
    # Make Pagy instance methods available as view helpers for backward compatibility
    # This allows calling @pagy methods directly in views

    # Pagy 9.3+ uses instance methods on the @pagy object instead of helper methods
    # Examples:
    #   @pagy.series_nav  - renders pagination links
    #   @pagy.info_tag    - renders pagination info
    #   @pagy.bootstrap_nav - renders Bootstrap-styled pagination
    #   @pagy.page_url(page) - generates URL for a specific page
  end
end
