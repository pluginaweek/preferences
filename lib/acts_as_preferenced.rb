module PluginAWeek #:nodoc:
  module Acts #:nodoc:
    module Preferenced #:nodoc:
      # An unknown preference definition was specified
      #
      class InvalidPreferenceDefinition < Exception
      end
      
      # An unknown preference type was specified
      #
      class InvalidPreferenceType < Exception
      end
      
      # An invalid preference value was specified
      #
      class InvalidPreferenceValue < Exception
      end
      
      def self.included(base) #:nodoc:
        base.extend(MacroMethods)
      end
      
      module SupportingClasses #:nodoc:
        #
        #
        class PreferenceDefinition
          attr_reader :name
          attr_reader :data_type
          attr_reader :possible_values
          attr_reader :default_value
          
          def initialize(name, type, options)
            options.assert_valid_keys(:type, :in, :within, :default, :for)
            
            @name = name
            @data_type = type
            @possible_values = type == :enum ? options[:in] || options[:within] : []
            @default_value = options[:default]
            
            if @default_value.nil?
              @default_value =
                case type
                when :boolean
                  false
                else
                  @possible_values.first
              end
            end
          end
        end
      end
      
      module MacroMethods
        #
        #
        def acts_as_preferenced(options = {})
          options.symbolize_keys!.assert_valid_keys(:on_error)
          
          model_name = "::#{self.name}"
          
          # Create the Preference Definition model
          const_set('PreferenceDefinition', Class.new(::PreferenceDefinition)).class_eval do
            has_many  :preferences,
                        :class_name => "#{model_name}::Preference",
                        :foreign_key => 'definition_id'
            
            def self.reloadable?
              false
            end
          end
          
          # Create the Preference model
          const_set('Preference', Class.new(::Preference)).class_eval do
            belongs_to  :owner,
                          :class_name => model_name,
                          :foreign_key => 'owner_id'
            
            belongs_to  :definition,
                          :class_name => "#{model_name}::PreferenceDefinition",
                          :foreign_key => 'definition_id'
            
            alias_method model_name.demodulize.underscore, :preferenced
            
            def self.reloadable?
              false
            end
          end
          
          write_inheritable_attribute :preference_definitions, {}
          write_inheritable_attribute :preference_error_handler, options[:on_error]
          
          has_many :preferences, :class_name => "#{model_name}::Preference", :foreign_key => 'owner_id' do
            #
            #
            def find_by_preferenced(definition_id, record)
              find_by_definition_id_and_preferenced_id_and_preferenced_type(definition_id, record.id, record.class.name)
            end
            
            #
            #
            def find_or_initialize_by_preferenced(definition_id, record)
              find_by_preferenced(definition_id, record) ||
              build(
                :definition_id => definition_id,
                :preferenced_id => record.id,
                :preferenced_type => record.class.name
              )
            end
          end
          
          extend PluginAWeek::Acts::Preferenced::ClassMethods
          include PluginAWeek::Acts::Preferenced::InstanceMethods
        end
      end
      
      module ClassMethods
        #
        #
        def data_type_for_preference(name, preferenced_type = nil)
          get_definition_value(name, preferenced_type, :data_type)
        end
        
        #
        #
        def possible_values_for_preference(name, preferenced_type = nil)
          get_definition_value(name, preferenced_type, :possible_values)
        end
        
        #
        #
        def default_value_for_preference(name, preferenced_type = nil)
          get_definition_value(name, preferenced_type, :default_value)
        end
        
        #
        #
        def valid_preference?(name, preferenced_type = nil)
          begin
            get_definition(name, preferenced_type)
            true
          rescue InvalidPreferenceDefinition
            false
          end
        end
        
        #
        #
        def preference(name, type, options = {})
          options.symbolize_keys!.reverse_merge!(
            :type => :any,
            :for => [self.name]
          )
          name = name.to_s
          
          definition = SupportingClasses::PreferenceDefinition.new(name, type, options)
          
          preference_definitions = read_inheritable_attribute(:preference_definitions)
          if (name_definitions = preference_definitions[name]).nil?
            name_definitions = preference_definitions[name] = {}
            define_preference_accessors(name, type)
          end
          
          Array(options[:for]).each {|type| name_definitions[type.constantize] = definition}
        end
        
        private
        VALID_PREFERENCE_TYPES = [:boolean, :enum, :any]
        
        #
        #
        def define_preference_accessors(name, type) #:nodoc:
          type = type.to_sym
          raise InvalidPreferenceType, "type must be #{VALID_PREFERENCE_TYPES.to_sentence(:connector => 'or')}, was: #{type}" if !VALID_PREFERENCE_TYPES.include?(type)
          
          if type.to_sym == :boolean
            prefix = 'prefers'
            suffix = '?'
            query_value = 'value?'
          else
            prefix = 'preferred'
            suffix = ''
            query_value = 'value'
          end
          
          definition = self::PreferenceDefinition.find_by_name(name)
          raise InvalidPreferenceDefinition, "Preference definition for #{name} not found for #{self.name}" if definition.nil?
          
          class_eval <<-end_eval
            def #{prefix}_#{name}#{suffix}
              #{prefix}_#{name}_for#{suffix}(self)
            end
            
            def #{prefix}_#{name}_for#{suffix}(record)
              preference = preferences.find_by_preferenced(#{definition.id}, record)
              preference ? preference.#{query_value} : self.class.default_value_for_preference('#{name}', record.class.name)
            end
            
            def #{prefix}_#{name}=(value, record = nil)
              preference = preferences.find_or_initialize_by_preferenced(#{definition.id}, record || self)
              preference.value = value
              success = preference.save
              
              if !success && handler = self.class.read_inheritable_attribute(:preference_error_handler)
                case handler
                  when :raise_exception
                    raise InvalidPreferenceValue, preference
                  when :add_errors_to_base
                    preference.errors.each {|attr, msg| errors.add(attr, msg)} if preference.errors.size > 0
                  else
                    handler.call(preference)
                end
              end
            end
          end_eval
        end
        
        #
        #
        def get_definition_value(name, preferenced_type, value_name) #:nodoc:
          definition = get_definition(name, preferenced_type)
          definition.send(value_name)
        end
        
        #
        #
        def get_definition(name, preferenced_type)
          preferenced_type = preferenced_type.nil? ? self : preferenced_type.constantize
          
          name_definitions = read_inheritable_attribute(:preference_definitions)[name]
          raise InvalidPreferenceDefinition, "Preference definition for #{name} not found for #{self.name}" if name_definitions.nil?
          
          preferenced_type = name_definitions.keys.find {|type| preferenced_type <= type}
          raise InvalidPreferenceDefinition, "#{preferenced_type} is not a preferenced type for #{name}" if preferenced_type.nil?
          
          name_definitions[preferenced_type]
        end
      end
      
      module InstanceMethods #:nodoc:
      end
    end
  end
end

ActiveRecord::Base.class_eval do
  include PluginAWeek::Acts::Preferenced
end