require 'sqlite3'
require 'active_support/inflector'


class Song
  # Class constant
  DB = {:conn => SQLite3::Database.new("db/music.db")} 

  # converts the returned records to an array of hashes
  DB[:conn].results_as_hash = true 

  def initialize(attributes)
    # initialize the value of each attribute
    attributes.each do |key, value|
      # invokes the setter method - self.attribute_name= value
      self.send("#{key}=", value) 
    end
  end

  def col_names_for_insert
    # deletes the "id" column
    # joins each column into a string
    # "col_a, col_b, ..."
    self.class.column_names.delete_if {|col| col == "id"}.join(", ")
  end

  def values_for_insert
    #returns an array of values of each atrribute except for the "id" value
    self.class.column_names.delete_if {|col| col == "id"}.map do |attr|
      # invokes the reader method - self.attribute_name
      self.send("#{attr}")  
    end
  end

  def save
    sql =  <<-SQL     
          INSERT INTO #{self.class.table_name} (#{col_names_for_insert}) 
          VALUES (?, ?)
        SQL

    if !self.id
      DB[:conn].execute(sql, values_for_insert)

      # retrieve the id of the last inserted record
      # assign the value to the id attribute
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
    # returns the pluralized name of the class in lowercase
    self.to_s.downcase.pluralize 
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
    # make a new instance of the class
    instance = self.new(attributes) # Song.new
    # persist the record to the database
    instance.save 
    instance
  end

  def self.find_by(attributes)
    values = [] # ["Street", "Hot Pink"]

    cols = attributes.collect do |key, value| # ["name", "album"]
      values << value
      key.to_s
    end

    cols_for_find = columns_for_find(cols).join(" AND ")

    # interpolates the table name to the SQL statement
    
    # "SELECT * FROM songs WHERE name = ? AND album = ?"
    sql = "SELECT * FROM #{table_name} WHERE #{cols_for_find}" 
    
    
    model_hash = DB[:conn].execute(sql, values)
    instatiate_records model_hash if !model_hash.empty?
  end

  def self.instatiate_records(records)
    if records.size > 1
      # return an array of instances if there is more than 1 record
      records.collect {|hash| self.new hash}
    else
      # return the instance if there is only 1 record
      self.new(records[0]) #Song.new
    end
  end

  # returns an array ["col1=?", "col2=?", ...]
  def self.columns_for_find(cols)
    # maps the column names with the placeholders - "col=?"
    cols.map {|col| "#{col} = ?"} 
  end

  def self.find(id)
    sql = "SELECT * FROM #{table_name} WHERE id = ?"
    result = DB[:conn].execute(sql, id)[0]

    Song.new(result)
  end

  def self.find_or_create_by(attributes)
    # returns an instance or collection of instances records are found
    # create a new record and return an instance if no records found
    find_by(attributes) || create(attributes) 
  end

  def self.column_names
    # Query table information
    sql = "PRAGMA table_info('#{table_name}')"
    table_info = DB[:conn].execute(sql)
  
    # map column names in an array
    column_names = table_info.map do |column|
      column["name"]
    end

    # We call #compact on that just to be safe and get rid of any nil values that may end up in our collection.
    column_names.compact
  end

  self.column_names.each do |col_name|
    # create attribute accessors for each column/attribute
    attr_accessor col_name.to_sym 
  end
  
end


song1 = Song.find_by(album: "Whatever", name: "Whatever")
p song1
