# frozen_string_literal: true
#https://ddnexus.github.io/pagy/toolbox/configuration/initializer/

# Default page size for API responses
Pagy::OPTIONS[:limit] = 25

# Maximum number of items per page
Pagy::OPTIONS[:max_limit] = 100
