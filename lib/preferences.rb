require 'preferences/preference_definition'

# Adds support for defining preferences on ActiveRecord models.
# 
# == Saving preferences
# 
# Preferences are not automatically saved when they are set.  You must save
# the record that the preferences were set on.
# 
# For example,
# 
#   class User < ActiveRecord::Base
#     preference :notifications
#   end
#   
#   u = User.new(:login => 'admin', :prefers_notifications => false)
#   u.save!
#   
#   u = User.find_by_login('admin')
#   u.attributes = {:prefers_notifications => true}
#   u.save!
# 
# == Validations
# 
# Since the generated accessors for a preference allow the preference to be
# treated just like regular ActiveRecord attributes, they can also be
# validated against in the same way.  For example,
# 
#   class User < ActiveRecord::Base
#     preference :color, :string
#     
#     validates_presence_of :preferred_color
#     validates_inclusion_of :preferred_color, :in => %w(red green blue)
#   end
#   
#   u = User.new
#   u.valid?                        # => false
#   u.errors.on(:preferred_color)   # => "can't be blank"
#   
#   u.preferred_color = 'white'
#   u.valid?                        # => false
#   u.errors.on(:preferred_color)   # => "is not included in the list"
#   
#   u.preferred_color = 'red'
#   u.valid?                        # => true
module Preferences
  module MacroMethods
    # Defines a new preference for all records in the model.  By default,
    # preferences are assumed to have a boolean data type, so all values will
    # be typecasted to true/false based on ActiveRecord rules.
    # 
    # Configuration options:
    # * <tt>:default</tt> - The default value for the preference. Default is nil.
    # 
    # == Examples
    # 
    # The example below shows the various ways to define a preference for a
    # particular model.
    # 
    #   class User < ActiveRecord::Base
    #     preference :notifications, :default => false
    #     preference :color, :string, :default => 'red'
    #     preference :favorite_number, :integer
    #     preference :data, :any # Allows any data type to be stored
    #   end
    # 
    # All preferences are also inherited by subclasses.
    # 
    # == Associations
    # 
    # After the first preference is defined, the following associations are
    # created for the model:
    # * +stored_preferences+ - A collection of all the custom preferences
    #   specified for a record.  This will not include default preferences
    #   unless they have been explicitly set.
    # 
    # == Named scopes
    # 
    # In addition to the above associations, the following named scopes get
    # generated for the model:
    # * +with_preferences+ - Finds all records with a given set of preferences
    # * +without_preferences+ - Finds all records without a given set of preferences
    # 
    # In addition to utilizing preferences stored in the database, each of the
    # above scopes also take into account the defaults that have been defined
    # for each preference.
    # 
    # Example:
    # 
    #   User.with_preferences(:notifications => true)
    #   User.with_preferences(:notifications => true, :color => 'blue')
    #   
    #   # Searching with group preferences
    #   car = Car.find(:first)
    #   User.with_preferences(car => {:color => 'blue'})
    #   User.with_preferences(:notifications => true, car => {:color => 'blue'})
    # 
    # == Generated accessors
    # 
    # In addition to calling <tt>prefers?</tt> and +preferred+ on a record,
    # you can also use the shortcut accessor methods that are generated when a
    # preference is defined.  For example,
    # 
    #   class User < ActiveRecord::Base
    #     preference :notifications
    #   end
    # 
    # ...generates the following methods:
    # * <tt>prefers_notifications?</tt> - Whether a value has been specified, i.e. <tt>record.prefers?(:notifications)</tt>
    # * <tt>prefers_notifications</tt> - The actual value stored, i.e. <tt>record.prefers(:notifications)</tt>
    # * <tt>prefers_notifications=(value)</tt> - Sets a new value, i.e. <tt>record.write_preference(:notifications, value)</tt>
    # * <tt>preferred_notifications?</tt> - Whether a value has been specified, i.e. <tt>record.preferred?(:notifications)</tt>
    # * <tt>preferred_notifications</tt> - The actual value stored, i.e. <tt>record.preferred(:notifications)</tt>
    # * <tt>preferred_notifications=(value)</tt> - Sets a new value, i.e. <tt>record.write_preference(:notifications, value)</tt>
    # 
    # Notice that there are two tenses used depending on the context of the
    # preference.  Conventionally, <tt>prefers_notifications?</tt> is better
    # for accessing boolean preferences, while +preferred_color+ is better for
    # accessing non-boolean preferences.
    # 
    # Example:
    # 
    #   user = User.find(:first)
    #   user.prefers_notifications?         # => false
    #   user.prefers_notifications          # => false
    #   user.preferred_color?               # => true
    #   user.preferred_color                # => 'red'
    #   user.preferred_color = 'blue'       # => 'blue'
    #   
    #   user.prefers_notifications = true
    #   
    #   car = Car.find(:first)
    #   user.preferred_color = 'red', car   # => 'red'
    #   user.preferred_color(car)           # => 'red'
    #   user.preferred_color?(car)          # => true
    #   
    #   user.save!  # => true
    def preference(name, *args)
      unless included_modules.include?(InstanceMethods)
        class_inheritable_hash :preference_definitions
        self.preference_definitions = {}
        
        class_inheritable_hash :default_preferences
        self.default_preferences = {}
        
        has_many :stored_preferences, :as => :owner, :class_name => 'Preference'
        
        after_save :update_preferences
        
        # Named scopes
        named_scope :with_preferences, lambda {|preferences| build_preference_scope(preferences)}
        named_scope :without_preferences, lambda {|preferences| build_preference_scope(preferences, true)}
        
        extend Preferences::ClassMethods
        include Preferences::InstanceMethods
      end
      
      # Create the definition
      name = name.to_s
      definition = PreferenceDefinition.new(name, *args)
      self.preference_definitions[name] = definition
      self.default_preferences[name] = definition.default_value
      
      # Create short-hand accessor methods, making sure that the name
      # is method-safe in terms of what characters are allowed
      name = name.gsub(/[^A-Za-z0-9_-]/, '').underscore
      
      # Query lookup
      define_method("preferred_#{name}?") do |*group|
        preferred?(name, group.first)
      end
      alias_method "prefers_#{name}?", "preferred_#{name}?"
      
      # Reader
      define_method("preferred_#{name}") do |*group|
        preferred(name, group.first)
      end
      alias_method "prefers_#{name}", "preferred_#{name}"
      
      # Writer
      define_method("preferred_#{name}=") do |*args|
        write_preference(*args.flatten.unshift(name))
      end
      alias_method "prefers_#{name}=", "preferred_#{name}="
      
      definition
    end
  end
  
  module ClassMethods #:nodoc:
    # Generates the scope for looking under records with a specific set of
    # preferences associated with them.
    # 
    # Note thate this is a bit more complicated than usual since the preference
    # definitions aren't in the database for joins, defaults need to be accounted
    # for, and querying for the the presence of multiple preferences requires
    # multiple joins.
    def build_preference_scope(preferences, inverse = false)
      joins = []
      statements = []
      values = []
      
      # Flatten the preferences for easier processing
      preferences = preferences.inject({}) do |result, (group, value)|
        if value.is_a?(Hash)
          value.each {|preference, value| result[[group, preference]] = value}
        else
          result[[nil, group]] = value
        end
        result
      end
      
      preferences.each do |(group, preference), value|
        preference = preference.to_s
        value = preference_definitions[preference.to_s].type_cast(value)
        is_default = default_preferences[preference.to_s] == value
        
        group_id, group_type = Preference.split_group(group)
        table = "preferences_#{group_id}_#{group_type}_#{preference}"
        
        # Since each preference is a different record, they need their own
        # join so that the proper conditions can be set
        joins << "LEFT JOIN preferences AS #{table} ON #{table}.owner_id = #{table_name}.#{primary_key} AND " + sanitize_sql(
          "#{table}.owner_type" => base_class.name.to_s,
          "#{table}.group_id" => group_id,
          "#{table}.group_type" => group_type,
          "#{table}.name" => preference
        )
        
        if inverse
          statements << "#{table}.id IS NOT NULL AND #{table}.value " + (value.nil? ? ' IS NOT NULL' : ' != ?') + (!is_default ? " OR #{table}.id IS NULL" : '')
        else
          statements << "#{table}.id IS NOT NULL AND #{table}.value " + (value.nil? ? ' IS NULL' : ' = ?') + (is_default ? " OR #{table}.id IS NULL" : '')
        end
        values << value unless value.nil?
      end
      
      sql = statements.map! {|statement| "(#{statement})"} * ' AND '
      {:joins => joins, :conditions => values.unshift(sql)}
    end
  end
  
  module InstanceMethods
    def self.included(base) #:nodoc:
      base.class_eval do
        alias_method :prefs, :preferences
      end
    end
    
    # Finds all preferences, including defaults, for the current record.  If
    # any custom group preferences have been stored, then this will include
    # all default preferences within that particular group.
    # 
    # == Examples
    # 
    # A user with no stored values:
    # 
    #   user = User.find(:first)
    #   user.preferences
    #   => {"language"=>"English", "color"=>nil}
    #   
    # A user with stored values for a particular group:
    # 
    #   user.preferred_color = 'red', 'cars'
    #   user.preferences
    #   => {"language"=>"English", "color"=>nil, "cars"=>{"language=>"English", "color"=>"red"}}
    #   
    # Getting preference values *just* for the owning record (i.e. excluding groups):
    # 
    #   user.preferences(nil)
    #   => {"language"=>"English", "color"=>nil}
    #   
    # Getting preference values for a particular group:
    # 
    #   user.preferences('cars')
    #   => {"language"=>"English", "color"=>"red"}
    def preferences(*args)
      group = args.first
      group = group.is_a?(Symbol) ? group.to_s : group
      
      unless @all_preferences_loaded
        if args.empty?
          # Looking up all available preferences
          loaded_preferences = stored_preferences
          @all_preferences_loaded = true
          
          preferences_group(nil).reverse_merge!(self.class.default_preferences.dup)
        elsif !preferences_group_loaded?(group)
          # Looking up group preferences
          group_id, group_type = Preference.split_group(group)
          loaded_preferences = stored_preferences.find(:all, :conditions => {:group_id => group_id, :group_type => group_type})
          
          preferences_group(group).reverse_merge!(self.class.default_preferences.dup)
        end
        
        # Find all stored preferences and hashify group -> name -> value
        loaded_preferences.inject(@preferences) do |preferences, preference|
          preferences[preference.group] ||= self.class.default_preferences.dup
          preferences[preference.group][preference.name] = preference.value
          preferences
        end if loaded_preferences
      end
      
      # Generate a deep copy
      if args.empty?
        @preferences.inject({}) do |preferences, (group, group_preferences)|
          if group.nil?
            preferences.merge!(group_preferences)
          else
            preferences[group] = group_preferences.dup
          end
          preferences
        end
      else
        @preferences[group].dup
      end
    end
    
    # Queries whether or not a value is present for the given preference.
    # This is dependent on how the value is type-casted.
    # 
    # == Examples
    # 
    #   class User < ActiveRecord::Base
    #     preference :color, :string, :default => 'red'
    #   end
    #   
    #   user = User.create
    #   user.preferred(:color)              # => "red"
    #   user.preferred?(:color)             # => true
    #   user.preferred?(:color, 'cars')     # => true
    #   user.preferred?(:color, Car.first)  # => true
    #   
    #   user.write_preference(:color, nil)
    #   user.preferred(:color)              # => nil
    #   user.preferred?(:color)             # => false
    def preferred?(name, group = nil)
      name = name.to_s
      group = group.is_a?(Symbol) ? group.to_s : group
      assert_valid_preference(name)
      
      value = preferred(name, group)
      preference_definitions[name].query(value)
    end
    alias_method :prefers?, :preferred?
    
    # Gets the actual value stored for the given preference, or the default
    # value if nothing is present.
    # 
    # == Examples
    # 
    #   class User < ActiveRecord::Base
    #     preference :color, :string, :default => 'red'
    #   end
    #   
    #   user = User.create
    #   user.preferred(:color)            # => "red"
    #   user.preferred(:color, 'cars')    # => "red"
    #   user.preferred(:color, Car.first) # => "red"
    #   
    #   user.write_preference(:color, 'blue')
    #   user.preferred(:color)            # => "blue"
    def preferred(name, group = nil)
      name = name.to_s
      group = group.is_a?(Symbol) ? group.to_s : group
      assert_valid_preference(name)
      
      if preferences_group(group).include?(name)
        # Value for this group/name has been written, but not saved yet:
        # grab from the pending values
        value = preferences_group(group)[name]
      else
        # Split the group being filtered
        group_id, group_type = Preference.split_group(group)
        
        # Grab the first preference; if it doesn't exist, use the default value
        unless preferences_group_loaded?(group)
          preference = stored_preferences.find(:first, :conditions => {:name => name, :group_id => group_id, :group_type => group_type})
        end
        
        value = preference ? preference.value : preference_definitions[name].default_value
        preferences_group(group)[name] = value
      end
      
      value
    end
    alias_method :prefers, :preferred
    
    # Sets a new value for the given preference.  The actual Preference record
    # is *not* created until this record is saved.  In this way, preferences
    # act *exactly* the same as attributes.  They can be written to and
    # validated against, but won't actually be written to the database until
    # the record is saved.
    # 
    # == Examples
    # 
    #   user = User.find(:first)
    #   user.write_preference(:color, 'red')              # => "red"
    #   user.save!
    #   
    #   user.write_preference(:color, 'blue', Car.first)  # => "blue"
    #   user.save!
    def write_preference(name, value, group = nil)
      name = name.to_s
      group = group.is_a?(Symbol) ? group.to_s : group
      assert_valid_preference(name)
      
      unless changed_preferences_group(group).include?(name)
        old = clone_preference_value(name, group)
        changed_preferences_group(group)[name] = old if preference_value_changed?(name, old, value)
      end
      
      preferences_group(group)[name] = value
      
      value
    end
    
    # Reloads the pereferences of this object as well as its attributes
    def reload(*args)
      result = super
      
      @all_preferences_loaded = false
      @preferences.clear if @preferences
      changed_preferences.clear
      
      result
    end
    
    private
      # Asserts that the given name is a valid preference in this model.  If it
      # is not, then an ArgumentError exception is raised.
      def assert_valid_preference(name)
        raise(ArgumentError, "Unknown preference: #{name}") unless preference_definitions.include?(name)
      end
      
      # Gets the set of preferences identified by the given group
      def preferences_group(group)
        @preferences ||= {}
        @preferences[group] ||= {}
      end
      
      # Determines whether the given group of preferences has already been
      # loaded from the database
      def preferences_group_loaded?(group)
        @all_preferences_loaded || preference_definitions.length == preferences_group(group).length
      end
      
      # Keeps track of all preferences that have been changed so that they can
      # be properly updated in the database.  Maps group -> preference -> value.
      def changed_preferences
        @changed_preferences ||= {}
      end
      
      # Gets the set of changed preferences identified by the given group
      def changed_preferences_group(group)
        changed_preferences[group] ||= {}
      end
      
      # Generates a clone of the current value stored for the preference with
      # the given name / group
      def clone_preference_value(name, group)
        value = preferred(name, group)
        value.duplicable? ? value.clone : value
      rescue TypeError, NoMethodError
        value
      end
      
      # Determines whether the old value is different from the new value for the
      # given preference.  This will use the typecasted value to determine
      # equality.
      def preference_value_changed?(name, old, value)
        definition = preference_definitions[name]
        if definition.type == :integer && old.nil?
          # NULL gets stored in database for blank (i.e. '') values. Hence we
          # don't record it as a change if the value changes from nil to ''.
          value = nil if value.blank?
        else
          value = definition.type_cast(value)
        end
        
        old != value
      end
      
      # Updates any preferences that have been changed/added since the record
      # was last saved
      def update_preferences
        changed_preferences.each do |group, preferences|
          group_id, group_type = Preference.split_group(group)
          
          preferences.keys.each do |name|
            attributes = {:name => name, :group_id => group_id, :group_type => group_type}
            
            # Find an existing preference or build a new one
            preference = stored_preferences.find(:first, :conditions => attributes) || stored_preferences.build(attributes)
            preference.value = preferred(name, group)
            preference.save!
          end
        end
        
        changed_preferences.clear
      end
  end
end

ActiveRecord::Base.class_eval do
  extend Preferences::MacroMethods
end
