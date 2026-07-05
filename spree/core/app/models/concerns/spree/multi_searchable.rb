module Spree
  # Constant alias for Spree::Searchable — remove in Spree 6.0.
  #
  # Lets legacy code and extensions reference the concern by its former name
  # after the Searchable rename. The concern itself lives in Spree::Searchable;
  # keeping the alias in its own file lets Zeitwerk manage (and reload) it,
  # avoiding the "already initialized constant" warning that a second constant
  # defined inside searchable.rb would raise.
  MultiSearchable = Searchable
end
