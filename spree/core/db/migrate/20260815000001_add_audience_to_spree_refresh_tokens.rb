class AddAudienceToSpreeRefreshTokens < ActiveRecord::Migration[8.1]
  # The API surface a refresh token was minted for. Without it a token minted
  # on one surface can be presented to another surface's refresh endpoint and
  # exchanged for that surface's access token — the cookie name is a
  # convention, not a boundary.
  #
  # Nullable: tokens issued before this column exists carry no audience and
  # are rejected on refresh, which costs their holders one login.
  # No index on the column: every lookup finds by `token`, which is already
  # uniquely indexed, and filters the single row it returns.
  def change
    add_column :spree_refresh_tokens, :audience, :string
  end
end
