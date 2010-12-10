ActiveRecord::Schema.define(:version => 0) do
    create_table :pages, :force => true do |t|
      t.column :title, :string, :limit => 255
      t.column :body, :text
      t.column :language, :string
    end
    
    create_table :page_translations, :force => true do |t|
      t.column :title, :string, :limit => 255
      t.column :body, :text
      t.column :page_id, :integer
      t.column :language, :string
    end
end