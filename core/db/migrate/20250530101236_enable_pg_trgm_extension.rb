class EnablePgTrgmExtension < ActiveRecord::Migration[8.0]
  def change
    if supports_extensions? && !extension_enabled?('pg_trgm') && extension_available?('pg_trgm')
      enable_extension 'pg_trgm'
    end
  end
end
