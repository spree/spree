# frozen_string_literal: true

# Pagy initializer for API v3
# https://ddnexus.github.io/pagy/docs/api/pagy/

# Default page size for API responses
Pagy.options[:limit] = 25

# Maximum number of items per page
Pagy.options[:limit_max] = 100
