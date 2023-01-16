class BackfillFriendlyIdSlugLocale < ActiveRecord::Migration[6.1]
  DEFAULT_LOCALE = 'en'

  def up
    ActiveRecord::Base.connection.execute("
    UPDATE friendly_id_slugs SET locale = '#{DEFAULT_LOCALE}'
                                          ")
  end

  def down
    ActiveRecord::Base.connection.execute("
    UPDATE friendly_id_slugs SET locale = NULL
                                          ")
  end
end
