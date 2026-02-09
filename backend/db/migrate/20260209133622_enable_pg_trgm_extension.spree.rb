# This migration comes from spree (originally 20250530101236)
class EnablePgTrgmExtension < ActiveRecord::Migration[7.2]
  def up
    if supports_extensions? && extension_available?('pg_trgm') && !extension_enabled?('pg_trgm')
      enable_extension 'pg_trgm'
    end
  end

  def down
    if supports_extensions? && extension_available?('pg_trgm') && extension_enabled?('pg_trgm')
      disable_extension 'pg_trgm'
    end
  end
end
