require 'sqlite3'
require 'active_support/inflector'


class Song
  DB = {:conn => SQLite3::Database.new("db/music.db")} # Class constant

  DB[:conn].results_as_hash = true # converts the returned records to an array of hashes

  def initialize(attributes)
    attributes.each do |key, value|
      self.send("#{key}=", value)
    end
  end

  def col_names_for_insert
    self.class.column_names.delete_if {|col| col == "id"}.join(", ")
  end

  def values_for_insert
    self.class.column_names.delete_if {|col| col == "id"}.map do |attr| #returns an array of values
      self.send("#{attr}")
    end
  end

  def save
    sql =  <<-SQL     
          INSERT INTO #{self.class.table_name} (#{col_names_for_insert}) VALUES (?, ?)
        SQL

    if !self.id
      DB[:conn].execute(sql, values_for_insert)
      self.id = DB[:conn].execute("SELECT last_insert_rowid() FROM #{self.class.table_name}")[0][0]
    end
  end

  def update
    sql =  <<-SQL
      UPDATE #{self.class.table_name} SET name = ?, album = ? where id = ?
    SQL

    DB[:conn].execute(sql, self.name, self.album, self.id) if self.id
  end


  def self.table_name
    self.to_s.downcase.pluralize # songs
  end

  def self.create_table
    sql =  <<-SQL     
        CREATE TABLE IF NOT EXISTS #{self.table_name} (
          id INTEGER PRIMARY KEY, 
          name TEXT, 
          album TEXT
        )
        SQL
    DB[:conn].execute(sql) 
  end

  def self.create(attributes)
    instance = self.new(attributes) # Song.new
    instance.save # persist the record to the database
    instance
  end

  def self.find_by(attributes)
    values = [] # ["Street", "Hot Pink"]

    cols = attributes.collect do |key, value| # ["name", "album"]
      values << value
      key.to_s
    end

    cols_for_find = columns_for_find(cols).join(" AND ")
    sql = "SELECT * FROM #{table_name} WHERE #{cols_for_find}" #"SELECT * FROM songs WHERE name = ? AND album = ?"
    
    
    model_hash = DB[:conn].execute(sql, values)
    instatiate_records model_hash if !model_hash.empty?
  end

  def self.instatiate_records(records)
    if records.size > 1
      records.collect {|hash| self.new hash}
    else
      self.new(records[0]) #Song.new
    end
  end

  # maps each column with a "=?"
  def self.columns_for_find(cols)
    cols.map {|col| "#{col} = ?"} #returns an array ["col"]
  end

  def self.find(id)
    sql = "SELECT * FROM #{table_name} WHERE id = ?"
    result = DB[:conn].execute(sql, id)[0]
    Song.new(result)
  end

  def self.find_or_create_by(attributes)
    find_by(attributes) || create(attributes)
  end

  def self.column_names
    sql = "PRAGMA table_info('#{table_name}')"
  
    table_info = DB[:conn].execute(sql)
    column_names = []
  
    column_names = table_info.map do |column|
      column["name"]
    end

    column_names.compact
  end

  self.column_names.each do |col_name|
    attr_accessor col_name.to_sym # create attribute accessors for :id, :name, :album
  end
  
end


song1 = Song.new(name: "Something")
song1.save
p song1
