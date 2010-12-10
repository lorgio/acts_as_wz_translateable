require File.join(File.dirname(__FILE__), 'abstract_unit')

if ActiveRecord::Base.connection.supports_migrations?
  class Thing < ActiveRecord::Base
    acts_as_wz_translateable
  end


  class MigrationTest < Test::Unit::TestCase
    def teardown
      if ActiveRecord::Base.connection.respond_to?(:initialize_schema_information)
        ActiveRecord::Base.connection.initialize_schema_information
        ActiveRecord::Base.connection.update "UPDATE schema_info SET version = 0"
      else
        ActiveRecord::Base.connection.initialize_schema_migrations_table
        ActiveRecord::Base.connection.assume_migrated_upto_version(0)
      end
      
      Thing.connection.drop_table "things" rescue nil
      Thing.connection.drop_table "thing_translations" rescue nil
      Thing.reset_column_information
    end
        
    def test_translated_migration
      ActiveRecord::Migrator.up(File.dirname(__FILE__) + '/fixtures/migrations/')

      # now lets take 'er back down
      ActiveRecord::Migrator.down(File.dirname(__FILE__) + '/fixtures/migrations/')
    end
  end
end
