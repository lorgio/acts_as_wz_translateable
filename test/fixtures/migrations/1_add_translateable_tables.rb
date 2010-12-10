class AddTranslateableTables < ActiveRecord::Migration
  def self.up
    create_table :things, :force => true do |t|
      t.column :title, :string, :limit => 255
      t.column :body, :text
    end
    Thing.create_translated_table
    Thing.drop_translated_table
  end
  
  def self.down
    create_table :things, :force => true do |t|
      t.column :title, :string, :limit => 255
      t.column :body, :text
    end

    Thing.create_translated_table
    Thing.drop_translated_table
  end
end