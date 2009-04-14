require "#{File.dirname(__FILE__)}/../test_helper"

class PreferencesTest < ActiveSupport::TestCase
  def setup
    User.preference :notifications, :boolean
    
    @user = User.new
  end
  
  def test_should_raise_exception_if_invalid_options_specified
    assert_raise(ArgumentError) {User.preference :notifications, :invalid => true}
    assert_raise(ArgumentError) {User.preference :notifications, :boolean, :invalid => true}
  end
  
  def test_should_create_preferred_query_method
    assert @user.respond_to?(:preferred_notifications?)
  end
  
  def test_should_create_prefers_query_method
    assert @user.respond_to?(:prefers_notifications?)
  end
  
  def test_should_create_preferred_reader
    assert @user.respond_to?(:preferred_notifications)
  end
  
  def test_should_create_prefers_reader
    assert @user.respond_to?(:prefers_notifications)
  end
  
  def test_should_create_preferred_writer
    assert @user.respond_to?(:preferred_notifications=)
  end
  
  def test_should_create_prefers_writer
    assert @user.respond_to?(:prefers_notifications=)
  end
  
  def test_should_create_preference_definitions
    assert User.respond_to?(:preference_definitions)
  end
  
  def test_should_create_default_preferences
    assert User.respond_to?(:default_preferences)
  end
  
  def test_should_include_new_definitions_in_preference_definitions
    assert_not_nil User.preference_definitions['notifications']
  end
  
  def teardown
    User.preference_definitions.delete('notifications')
    User.default_preferences.delete('notifications')
  end
end

class UserByDefaultTest < ActiveSupport::TestCase
  def setup
    @user = User.new
  end
  
  def test_should_not_prefer_hot_salsa
    assert_nil @user.preferred_hot_salsa
    assert_nil @user.prefers_hot_salsa
  end
  
  def test_should_prefer_dark_chocolate
    assert_equal true, @user.preferred_dark_chocolate
    assert_equal true, @user.prefers_dark_chocolate
  end
  
  def test_should_not_have_a_preferred_color
    assert_nil @user.preferred_color
  end
  
  def test_should_not_have_a_preferred_car
    assert_nil @user.preferred_car
  end
  
  def test_should_have_a_preferred_language
    assert_equal 'English', @user.preferred_language
  end
  
  def test_should_have_only_default_preferences
    expected = {
      'hot_salsa' => nil,
      'dark_chocolate' => true,
      'color' => nil,
      'car' => nil,
      'language' => 'English'
    }
    
    assert_equal expected, @user.preferences
  end
end

class UserTest < ActiveSupport::TestCase
  def setup
    @user = new_user
  end
  
  def test_should_be_able_to_change_hot_salsa_preference
    @user.prefers_hot_salsa = false
    assert_equal false, @user.prefers_hot_salsa?
    
    @user.prefers_hot_salsa = true
    assert_equal true, @user.prefers_hot_salsa?
  end
  
  def test_should_be_able_to_change_dark_chocolate_preference
    @user.prefers_dark_chocolate = false
    assert_equal false, @user.prefers_dark_chocolate?
    
    @user.prefers_dark_chocolate = true
    assert_equal true, @user.prefers_dark_chocolate?
  end
  
  def test_should_be_able_to_change_color_preference
    @user.preferred_color = 'blue'
    assert_equal 'blue', @user.preferred_color
  end
  
  def test_should_be_able_to_change_car_preference
    @user.preferred_car = 1
    assert_equal 1, @user.preferred_car
  end
  
  def test_should_be_able_to_change_language_preference
    @user.preferred_language = 'Latin'
    assert_equal 'Latin', @user.preferred_language
  end
  
  def test_should_be_able_to_use_generic_preferred_query_method
    @user.prefers_hot_salsa = true
    assert @user.preferred?(:hot_salsa)
  end
  
  def test_should_be_able_to_use_generic_prefers_query_method
    @user.prefers_hot_salsa = true
    assert @user.prefers?(:hot_salsa)
  end
  
  def test_should_be_able_to_use_generic_preferred_method
    @user.preferred_color = 'blue'
    assert_equal 'blue', @user.preferred(:color)
  end
  
  def test_should_be_able_to_use_generic_prefers_method
    @user.preferred_color = 'blue'
    assert_equal 'blue', @user.prefers(:color)
  end
  
  def test_should_be_able_to_use_generic_set_preference_method
    @user.set_preference(:color, 'blue')
    assert_equal 'blue', @user.preferred(:color)
  end
  
  def test_should_still_be_new_record_after_changing_preference
    @user.preferred_color = 'blue'
    assert @user.new_record?
    assert @user.stored_preferences.empty?
  end
end

class UserAfterBeingCreatedTest < ActiveSupport::TestCase
  def setup
    @user = create_user
  end
  
  def test_should_not_have_any_stored_preferences
    assert @user.stored_preferences.empty?
  end
end

class UserWithoutStoredPreferencesTest < ActiveSupport::TestCase
  def setup
    @user = create_user
  end
  
  def test_should_not_prefer_hot_salsa
    assert_nil @user.preferred_hot_salsa
  end
  
  def test_should_prefer_dark_chocolate
    assert_equal true, @user.preferred_dark_chocolate
  end
  
  def test_should_not_have_a_preferred_color
    assert_nil @user.preferred_color
  end
  
  def test_should_not_have_a_preferred_car
    assert_nil @user.preferred_car
  end
  
  def test_should_have_a_preferred_language
    assert_equal 'English', @user.preferred_language
  end
  
  def test_should_not_save_record_after_changing_preference
    @user.preferred_language = 'Latin'
    
    user = User.find(@user.id)
    assert_equal 'English', user.preferred_language
    assert user.stored_preferences.empty?
  end
end

class UserWithStoredPreferencesTest < ActiveSupport::TestCase
  def setup
    @user = create_user
    @user.preferred_language = 'Latin'
    @user.save!
  end
  
  def test_should_have_stored_preferences
    assert_equal 1, @user.stored_preferences.size
  end
  
  def test_should_include_custom_and_default_preferences_in_preferences
    expected = {
      'hot_salsa' => nil,
      'dark_chocolate' => true,
      'color' => nil,
      'car' => nil,
      'language' => 'Latin'
    }
    
    assert_equal expected, @user.preferences
  end
  
  def test_should_use_preferences_for_prefs
    expected = {
      'hot_salsa' => nil,
      'dark_chocolate' => true,
      'color' => nil,
      'car' => nil,
      'language' => 'Latin'
    }
    
    assert_equal expected, @user.prefs
  end
  
  def test_should_not_remove_preference_if_set_to_default
    @user.preferred_language = 'English'
    @user.save!
    @user.reload
    assert_equal 1, @user.stored_preferences.size
  end
  
  def test_should_not_remove_preference_if_set_to_nil
    @user.preferred_language = nil
    @user.save!
    @user.reload
    assert_equal 1, @user.stored_preferences.size
  end
  
  def test_should_not_save_preference_if_model_is_not_saved
    @user.preferred_language = 'English'
    
    user = User.find(@user.id)
    assert_equal 'Latin', user.preferred_language
  end
  
  def test_should_modify_existing_preferences_when_saved
    @user.preferred_language = 'Spanish'
    assert @user.save
    
    @user.reload
    assert_equal 'Spanish', @user.preferred_language
    assert_equal 1, @user.stored_preferences.size
  end
  
  def test_should_add_new_preferences_when_saved
    @user.preferred_color = 'blue'
    assert @user.save
    
    @user.reload
    assert_equal 'blue', @user.preferred_color
    assert_equal 2, @user.stored_preferences.size
  end
end

class UserWithStoredPreferencesForBasicGroupsTest < ActiveSupport::TestCase
  def setup
    @user = create_user
    @user.preferred_color = 'red', 'cars'
    @user.save!
  end
  
  def test_should_have_stored_preferences
    assert_equal 1, @user.stored_preferences.size
  end
  
  def test_should_include_group_in_preferences
    expected = {
      'hot_salsa' => nil,
      'dark_chocolate' => true,
      'color' => nil,
      'car' => nil,
      'language' => 'English',
      'cars' => {
        'hot_salsa' => nil,
        'dark_chocolate' => true,
        'color' => 'red',
        'car' => nil,
        'language' => 'English'
      }
    }
    
    assert_equal expected, @user.preferences
  end
  
  def test_should_be_able_to_show_all_preferences_just_for_the_owner
    expected = {
      'hot_salsa' => nil,
      'dark_chocolate' => true,
      'color' => nil,
      'car' => nil,
      'language' => 'English'
    }
    
    assert_equal expected, @user.preferences(nil)
  end
  
  def test_should_be_able_to_show_all_preferences_for_a_single_group
    expected = {
      'hot_salsa' => nil,
      'dark_chocolate' => true,
      'color' => 'red',
      'car' => nil,
      'language' => 'English'
    }
    
    assert_equal expected, @user.preferences('cars')
  end
  
  def test_should_not_have_preference_without_group
    assert_nil @user.preferred_color
  end
  
  def test_should_have_preference_with_group
    assert_equal 'red', @user.preferred_color('cars')
  end
  
  def test_should_modify_existing_preferences_when_saved
    @user.preferred_color = 'blue', 'cars'
    assert @user.save
    
    @user.reload
    assert_equal 'blue', @user.preferred_color('cars')
    assert_equal 1, @user.stored_preferences.size
  end
  
  def test_should_be_able_to_differentiate_between_groups
    @user.preferred_color = 'blue', 'boats'
    assert @user.save
    
    @user.reload
    assert_equal 'red', @user.preferred_color('cars')
    assert_equal 'blue', @user.preferred_color('boats')
    assert_equal 2, @user.stored_preferences.size
  end
end

class UserWithStoredPreferencesForActiveRecordGroupsTest < ActiveSupport::TestCase
  def setup
    @car = create_car
    
    @user = create_user
    @user.preferred_color = 'red', @car
    @user.save!
  end
  
  def test_should_have_stored_preferences
    assert_equal 1, @user.stored_preferences.size
  end
  
  def test_should_have_preferences_for_group
    expected = {
      'hot_salsa' => nil,
      'dark_chocolate' => true,
      'color' => nil,
      'car' => nil,
      'language' => 'English',
      @car => {
        'hot_salsa' => nil,
        'dark_chocolate' => true,
        'color' => 'red',
        'car' => nil,
        'language' => 'English'
      }
    }
    
    assert_equal expected, @user.preferences
  end
  
  def test_should_not_have_preference_without_group
    assert_nil @user.preferred_color
  end
  
  def test_should_have_preference_with_group
    assert_equal 'red', @user.preferred_color(@car)
  end
  
  def test_should_modify_existing_preferences_when_saved
    @user.preferred_color = 'blue', @car
    assert @user.save
    
    @user.reload
    assert_equal 'blue', @user.preferred_color(@car)
    assert_equal 1, @user.stored_preferences.size
  end
  
  def test_should_be_able_to_differentiate_between_groups
    @different_car = create_car
    
    @user.preferred_color = 'blue', @different_car
    assert @user.save
    
    @user.reload
    assert_equal 'red', @user.preferred_color(@car)
    assert_equal 'blue', @user.preferred_color(@different_car)
    assert_equal 2, @user.stored_preferences.size
  end
end
