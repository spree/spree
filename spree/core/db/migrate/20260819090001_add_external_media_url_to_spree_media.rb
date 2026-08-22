class AddExternalMediaUrlToSpreeMedia < ActiveRecord::Migration[8.1]
  def change
    # The address of media whose bytes live somewhere else — a DAM holding the
    # master image, and in future a self-hosted video file. Not narrowed to
    # images: the column answers "where is this media served from", and the
    # media_type says what it is.
    #
    # Beside external_video_url rather than replacing it: that one holds an
    # embed link Spree parses and validates as YouTube or Vimeo, which is a
    # different thing from an address to fetch bytes from.
    add_column :spree_media, :external_media_url, :string
  end
end
