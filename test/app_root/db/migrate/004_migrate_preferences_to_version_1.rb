class MigratePreferencesToVersion1 < ActiveRecord::Migration
  def self.up
    Rails::Plugin.find(:preferences).migrate(1)
  end
  
  def self.down
    Rails::Plugin.find(:preferences).migrate(0)
  end
end
