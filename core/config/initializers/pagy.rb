# frozen_string_literal: true

# Pagy Configuration
# See https://ddnexus.github.io/pagy/docs/api/pagy

# Set default items per page
Pagy.options[:items] = 20

# Set default page parameter key
Pagy.options[:page_key] = 'page'

# Set default items per page parameter key
Pagy.options[:items_key] = 'per_page'

# Enable size for the page links
Pagy.options[:size] = 7
