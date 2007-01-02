class CreatePreferenceDefinitions < ActiveRecord::Migration
  def self.up
    create_table :preference_definitions do |t|
      t.column :name,         :string,    :null => false
      t.column :description,  :text
      t.column :type,         :string,    :null => false
      t.column :created_at,   :timestamp, :null => false
      t.column :updated_at,   :datetime,  :null => false
      t.column :deleted_at,   :datetime
    end
    add_index :preference_definitions, [:type, :name], :unique => true, :name => 'unique_preference_definitions'
  end
  
  def self.down
    drop_table :preference_definitions
  end
end
