=begin
wz_translateable.rb
Copyright 2010 wollzelle GmbH (http://wollzelle.com). All rights reserved.
=end

module ActiveRecord
  module Acts 
    module WzTranslateable

      # default language english
      DEFAULT_LANGUAGE   =    'en'

      def self.included(base) # :nodoc:
        base.extend ClassMethods
        
        mattr_accessor :configuration
        mattr_accessor :current_language
      end

      module ClassMethods

        def acts_as_wz_translateable(options = {})

          return if self.included_modules.include?(ActiveRecord::Acts::WzTranslateable::ActMethods)
          send :include, ActiveRecord::Acts::WzTranslateable::ActMethods
          @current_translation = nil
          
          cattr_accessor :translation_class_name, :translation_table_name, :language_column, :translation_join_alias,
                         :translation_sequence_name, :translation_foreign_key, :translation_association_options,
                         :default_language

          self.translation_class_name        = options[:class_name]  || "Translation"
          self.translation_table_name        = options[:table_name]  || "#{table_name_prefix}#{base_class.name.demodulize.underscore}_translations#{table_name_suffix}"
          self.language_column               = options[:language_column] || 'language'
          self.translation_sequence_name     = options[:sequence_name]
          self.translation_foreign_key       = options[:foreign_key] || self.to_s.foreign_key
          self.translation_join_alias        = options[:translation_join_alias] || "#{self.table_name}_t"
          self.default_language              = options[:default_language] || DEFAULT_LANGUAGE
          
          self.translation_association_options  = {
            :class_name  => "#{self.to_s}::#{translation_class_name}",
            :foreign_key => self.translation_foreign_key,
            :dependent   => :delete_all,
            :autosave    => true,
            :order       => "#{self.translation_table_name}.#{self.language_column}"
            }.merge(options[:association_options] || {})
          
          # create the dynamic translation model
          const_set(translation_class_name, Class.new(self.superclass)).class_eval do
            named_scope :in_language, lambda {|language| {:conditions => {:language => language.to_s} } }
            named_scope :in_current_language, lambda { {:conditions => {:language => original_class.get_current_language} } }
            named_scope :in_default_language, lambda { {:conditions => {:language => original_class.default_language} } }
            named_scope :without_default_language, lambda { {:conditions => ["#{self.table_name}.language <> :language", {:language => original_class.default_language}] } }

            def self.reloadable? ; false ; end

            # find translation
            def translate_to(language)
              self.class.find :first,
              :conditions => ["#{original_class.translation_foreign_key} = :foreign_key and language = :language", {:foreign_key => self.send(original_class.translation_foreign_key), :language => language}]
            end
          end

          class_eval <<-CLASS_METHODS
          has_many :translations, translation_association_options
          
          accepts_nested_attributes_for :translations, :allow_destroy => true
          
          named_scope :join_translation, lambda { |language| { 
              :select => "#{self.table_name}.*, \#{self.extended_columns_select(language)}",
              :joins => "LEFT \#{self.translation_join_str(language)}"
            } }

          named_scope :exclusive_translation, lambda { |language| { 
              :select => "#{self.table_name}.*, \#{self.extended_columns_select(language)},
              :joins  => "\#{self.translation_join_str(language)}"
            } }

          named_scope :join_current_translation, lambda { { 
              :select => "#{self.table_name}.*, \#{self.extended_columns_select(self.get_current_language)}",
              :joins => "LEFT \#{self.translation_join_str(self.get_current_language)}"
            } }

          before_save  :set_default_language
          after_save   :after_save_main_object   
          alias_method_chain :clone, :translation           

          CLASS_METHODS

          add_dynamic_finder_methods

          translation_class.cattr_accessor :original_class
          translation_class.original_class = self
          translation_class.set_table_name translation_table_name
          translation_class.belongs_to self.to_s.demodulize.underscore.to_sym, 
                                       :class_name  => "::#{self.to_s}", 
                                       :foreign_key => translation_foreign_key
          translation_class.send :include, options[:extend]  if options[:extend].is_a?(Module)
          translation_class.set_sequence_name translation_sequence_name if translation_sequence_name
        end # end of acts_as
        
        def get_current_language
          (ActiveRecord::Acts::WzTranslateable.current_language || I18n.locale).to_s
        end

      end # end of ClassMethods
      
      module ActMethods
        def self.included(base) # :nodoc:
          base.extend ClassMethods
        end
        
        # clones also existing translations
        def clone_with_translation
          new_obj = self.clone_without_translation
          
          self.translations.each do |translation|
            new_obj.translations << translation.clone
          end
          new_obj
        end
        
        def assign_translations(source)
          transaction do
            self.translations.each do |translation|
              # remove translations, which not exist in source
              # assign value to those, which exist
              source_trans = source.translations.detect {|entry| entry.language == translation.language}
              if (source_trans)
                self.class.copy_translation_fields(source_trans,translation)
              else
                translation.destroy
              end  
            end
            
            # add not existing translations from source
            source.translations.each do |translation|
              self.translations << translation.clone unless self.translations.detect {|entry| entry.language == translation.language}
            end
          end  
        end

        # get a specific translation an buffers it in class var
        # returns nil if language is not found 
        def get_translation(language)
          lang = language.to_s
          @current_translation ||= self.translations.in_language(lang).first
          if (!@current_translation.nil?) and (@current_translation[self.language_column] != lang) then
            @current_translation = self.translations.in_language(lang).first
          else
            @current_translation
          end
        end  
        
        # get a specific field translation
        # returns nil if language is not found
        def get_field_translation(field, options = {})
          join_name = options[:join_alias] || self.translation_join_alias
          lang = options[:language] || self["#{join_name}__lang"] || self.class.get_current_language
          
          if (self.loaded_with_translation?(lang, options))
            if (options[:when_missing_use_default] && self["#{join_name}_#{self.language_column}"].nil?)
              self[field]
            else
              self["#{join_name}_#{field}"]
            end
          else
            trans = self.get_translation(lang)
            if (options[:when_missing_use_default] && trans.nil?)
              self[field]
            else
              trans[field]
            end
          end 
        end
        
        def loaded_with_translation?(language, options = {})
          join_name = options[:join_alias] || self.translation_join_alias
          (self["#{join_name}__lang"] || '') == language.to_s
        end

        def save_default_translation?
          new_record? || self.class.translated_columns.detect { |column| send("#{column.name}_changed?") }
        end

        def save_default_translation
          trans = self.translations.in_language(self.language || self.default_language).first || self.class.translation_class.new
          self.class.copy_translation_fields(self, trans)
          trans[self.class.language_column] = self[self.class.language_column]
          trans[self.class.translation_foreign_key] = id
          trans.save
        end

        def set_default_language
          self[self.language_column] ||= self.default_language # no specific main language can be used for fallback
        end

        # Saves a default translation of the model in the translation table.  
        # It's called in the after_save callback
        def after_save_main_object
          if save_default_translation?
            save_default_translation
          end
        end

        module ClassMethods
          
          # Returns an array of columns definitions which are translated.
          def translated_columns
            @translated_columns ||= self.translation_class.content_columns.select { |c| !['id', 'language', translation_foreign_key, 'created_at', 'updated_at'].include?(c.name) } rescue [] # if table does not exists
          end

          def translation_current_join_str(options = {})
            translation_join_str(self.get_current_language, options)
          end
          
          # get JOIN string for translation
          def translation_join_str(language, options = {})
            main_tname = options[:table_alias] || self.table_name
            tname = options[:translation_table_alias] || self.translation_table_name
            "JOIN #{tname} ON #{main_tname}.#{self.primary_key}=#{tname}.#{self.translation_foreign_key} and #{tname}.#{self.language_column}='#{language.to_s}'"
          end
          
          # copies all translated fields to destination (main object or translation) 
          def copy_translation_fields(source, destination)
            self.translated_columns.each do |col|
              destination.send("#{col.name}=", source.send(col.name)) if source.has_attribute?(col.name)
            end
          end
          
          # get extended columns select for translation join
          # add detection language column {join_name}__lang
          def extended_columns_select(language = nil, options = {})
            lang = (language || self.get_current_language).to_s
            tname = options[:translation_table_alias] || translation_table_name
            join_name = options[:join_alias] || translation_join_alias
            columns = self.translated_columns.collect {|c| c.name }
            columns << self.language_column
            ["'#{lang}' as #{join_name}__lang", translation_columns_for_select(columns, options)].join(',')
          end
          
          # get select string for columns
          def translation_columns_for_select(columns, options = {})
            tname = options[:translation_table_alias] || translation_table_name
            join_name = options[:join_alias] || translation_join_alias
            columns.collect {|column| "#{tname}.#{column} as #{join_name}_#{column}" }.join(',')
          end

          # Returns an instance of the dynamic translated model
          def translation_class
            const_get translation_class_name
          end

          # Rake migration task to create the translation table using options passed to acts_as_wz_translated
          def create_translated_table(create_table_options = {})
            # create translatin column in main table, if it does not exist
            if !self.columns.find { |c| [self.language_column.to_s].include? c.name }
              self.connection.add_column table_name, self.language_column, :string
            end

            return if self.connection.table_exists?(translation_table_name)

            self.connection.create_table(translation_table_name, create_table_options) do |t|
              t.column translation_foreign_key, :integer
              t.column language_column, :string
              t.timestamps
            end
            
            trans_columns = if create_table_options[:columns]
              self.content_columns.select {|col| create_table_options[:columns].include?(col.name.to_sym) } 
            else
              self.content_columns
            end

            trans_columns.each do |col| 
              if !((self.connection.columns self.translation_table_name.to_sym).include?(col.name)) then
                self.connection.add_column translation_table_name, col.name, col.type, 
                :limit     => col.limit, 
                :default   => col.default,
                :scale     => col.scale,
                :precision => col.precision
              end
            end

            self.connection.add_index translation_table_name, translation_foreign_key
          end
          
          # create default translation for all entries
          def create_default_language_entries
            self.all.each {|entry| entry.save_default_translation}
          end

          # Rake migration task to drop the versioned table
          def drop_translated_table
            self.connection.drop_table translation_table_name
          end

          private
          def add_dynamic_finder_methods
            translated_columns.each do |column|
              attr_name = column.name
              find_by_function = "self.find_with_translation_by_#{attr_name}(language, attribute_value, options = {} )"
              find_or_create_function = "self.find_or_create_with_translation_by_#{attr_name}(language, attribute_value, options ={} )"

              class_eval <<-FINDER_METHODS
              def #{find_by_function}
                self.first(:joins => [:translations],
                :readonly => false,
                :conditions =>{:#{translation_table_name} => { :#{attr_name} => attribute_value, :language => language }}.merge(options[:conditions] || {}) )
              end

              def find_or_create_translation(language)
                #{translation_class}.find_or_create_by_#{translation_foreign_key}_and_language(self.id,language)
              end 

              def #{find_or_create_function}
                translation_found = #{find_by_function}

                object_found ||= self.create("#{attr_name}".to_sym => @@translation_wrapper )
                object_found
              end

              FINDER_METHODS
            end
          end
        end
      end
    end
  end
end


