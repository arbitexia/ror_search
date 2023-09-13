class TSV
  attr_reader :filepath

  def initialize(filepath)
    @filepath = filepath
  end

  def parse
    f = open(filepath)

    # headers = f.gets.strip.split("\t")
    f.each do |line|
      values = line.split("\t").map do |value|
        value = value.strip
        value = value[1...-1] if value.chars.first == '"' && value.chars.last == '"'
        value
      end
      # fields = Hash[headers.zip(values)]
      yield values
    end
  end
end

module DatabaseSearcher
  def database_path
    Rails.root.join("db/#{db_name.downcase}.db").to_s
  end

  def importing_database_path
    Rails.root.join("db/#{db_name.downcase}.importing.db").to_s
  end

  def database_exists?
    File.exist?(database_path)
  end

  def db
    regenerate_database unless database_exists?
    @db ||= SQLite3::Database.new(database_path)
    @db.results_as_hash = true
    @db
  end

  def db_column_names
    db.execute('pragma table_info(entries)').map { |column| column['name'] }
  end

  def regenerate_database
    puts "regenerating #{db_name} db"

    tmp_file = Tempfile.new([db_name.downcase, '.csv'])

    # temp hack to not verify certs when downloading from these sites
    old_verify_peer = OpenSSL::SSL::VERIFY_PEER
    OpenSSL::SSL.const_set(:VERIFY_PEER, OpenSSL::SSL::VERIFY_NONE)
    open(db_refresh_url) do |url_file|
      s = url_file.read.force_encoding('iso-8859-1')

      if self == DHSARSearcher
        # fix CSVs with malformatted double quotes. basically when you have something on a single line between double quotes, treat it as just single quotes.
        # e.g.:
        # "OIG","","Yoser, Seth ",""Memphis TN,"","AR","38120"
        # puts s.split("\n").first if i == 0
        s = s.gsub(/""([^",][^\n]+)""/, '"\1"')
        # puts s.split("\n").first if i == 0
        s = s.gsub(/([^,\r\n])"([^,\r\n])/, "\\1'\\2")
        # puts s.split("\n").first if i == 0
        # puts '=' * 80 if i == 0
        # i = 1
      end

      tmp_file.write(s)
    end
    tmp_file.rewind
    OpenSSL::SSL.const_set(:VERIFY_PEER, old_verify_peer)

    File.delete(importing_database_path) if File.exist?(importing_database_path)
    db = SQLite3::Database.new(importing_database_path.to_s)

    columns = nil
    if db_refresh_url.to_s.end_with?('tsv')
      tsv = TSV.new(tmp_file)

      rows_processed = 0
      tsv.parse do |row|
        next if row.count <= 1

        columns = process_row(row, columns, db)
        rows_processed += 1
      end
      puts "#{rows_processed} rows processed from TSV"
    elsif db_refresh_url.to_s.end_with?('xml')
      xml = Ox.parse(tmp_file.read)

      has_created_table = false

      # OFAC special case
      xml.locate('sdnList/sdnEntry').each do |sdn_element|
        aka_elements = sdn_element.locate('akaList/aka')

        uid = sdn_element.locate('uid').first&.text
        type = sdn_element.locate('sdnType').first&.text
        programs = sdn_element.locate('programList/program').map(&:text).join(', ')
        address = sdn_element.locate('addressList/address/address1').first&.text

        all_elements = [sdn_element] + aka_elements

        all_elements.each do |el|
          hash = {
            'uid' => uid,
            'first_name' => el.locate('firstName').first&.text,
            'last_name' => el.locate('lastName').first&.text,
            'type' => type,
            'programs' => programs,
            'address' => address
          }

          unless has_created_table
            create_entries_table(hash.keys, db)
            has_created_table = true
          end

          columns = hash.keys.concat(hash.keys.map { |key| "#{key}_clean" })
          row = hash.values

          process_row(row, columns, db)
        end
      end
    else
      # csv
      rows_processed = 0
      CSV.foreach(tmp_file.path) do |row|
        next if row.count <= 1

        columns = process_row(row, columns, db)
        rows_processed += 1
      end
      puts "#{rows_processed} rows processed from CSV"
    end

    FileUtils.cp(importing_database_path, database_path)
    File.delete(importing_database_path)

    @db = SQLite3::Database.new(database_path)
  end

  def create_entries_table(columns, db)
    columns = columns.concat(columns.map { |col| "#{col}_clean" })
    create_columns = columns.map { |column| "#{column} TEXT" }.join(',')
    p create_columns
    db.execute("create table entries (#{create_columns});")
  end

  def process_row(row, columns, db)
    if columns.nil?
      columns = row.map(&:strip).map { |col| col.downcase.gsub(' ', '_').gsub(/\W/, '') }
      create_entries_table(columns, db)
    else
      placeholders = (['?'] * row.count * 2).join(',')

      row.map! { |value| value&.force_encoding('UTF-8') } if db_name == 'OFAC'

      row_clean = row.map do |val|
        ApplicationRecord.sanitize_name(val) if val
      end

      begin
        db.execute("insert into entries (#{columns.join(',')}) values (#{placeholders})", row.concat(row_clean))
      rescue StandardError
        p columns
        p row
      end
    end

    columns
  end
end
