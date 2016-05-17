CanonicalRails.setup do |config|
  # http://en.wikipedia.org/wiki/URL_normalization
  # Trailing slash represents semantics of a directory, ie a collection view - implying an :index get route;
  # otherwise we have to assume semantics of an instance of a resource type, a member view - implying a :show get route
  #
  # Acts as a whitelist for routes to have trailing slashes

  config.collection_actions # = [:index]

  # Parameter spamming can cause index dilution by creating seemingly different URLs with identical or near-identical content.
  # Unless whitelisted, these parameters will be omitted

  config.whitelisted_parameters = [:keywords, :page, :search, :taxon]
end
