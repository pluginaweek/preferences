class PreferencesGenerator < Rails::Generators::Base
  include Rails::Generators::Migration

  source_root File.expand_path("../templates", __FILE__)

  def self.next_migration_number(dirname)
    if ActiveRecord::Base.timestamped_migrations
      Time.now.utc.strftime("%Y%m%d%H%M%S")
    else
      "%.3d" % (current_migration_number(dirname) + 1)
    end
  end

  def create_migration_file
    migration_template 'create_preferences.rb', "db/migrate/create_preferences.rb"
  end
end
