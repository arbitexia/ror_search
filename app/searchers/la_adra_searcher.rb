require 'csv'

module LaAdraSearcher
  include DatabaseSearcher
  extend self

  def db_name
    'LAADRA'
  end

  def db_refresh_url
    generate_csv
  end

  def page_url
    'https://la-adra.org/disciplinary-actions/'
  end

  def search_employee(employee)
    search(employee.last_name_clean, employee.first_name_clean, employee.la_license_type,
           employee.la_license_number)
  end

  alias search_vendor search_employee

  private

  def generate_csv
    tmp_file = Tempfile.open([db_name, '.csv'])
    response = RestClient::Request.execute(method: :get,
                                          url: page_url,
                                          timeout: 120)
    html = Nokogiri::HTML(response.body)
    tables = html.search('table')
    raise StandardError('Unexpected multiple tables') if tables.count > 1

    table = tables.first

    CSV.open(tmp_file, 'w') do |csv|
      table.search('tr').each do |tr|
        tr_row = []
        cells = tr.search('th, td')
        cells.each do |cell|
          tr_row.push cell.text.strip
        end
        csv << tr_row
      end
    end
    tmp_file.path
  end

  # A positive would only be if credential + first or last name match.
  # A potential if first and last name match OR if only credential matches.
  def search(last_name_clean, first_name_clean, la_license_type, la_license_number)
    positives = []
    potentials = []

    if la_license_type == 'adra'
      # I can only find positives if I have a valid license to look for
      if first_name_clean && last_name_clean
        positives = db.execute("SELECT * FROM entries WHERE (first_name_clean LIKE ? AND credential_ = ?) OR (last_name_clean LIKE ? AND credential_ = ?)",
                         "#{first_name_clean}%", la_license_number, "#{last_name_clean}%", la_license_number)

      else
        default_value = "Unknown"
  
        if first_name_clean.nil? && last_name_clean.nil?
          puts "Both first_name_clean and last_name_clean are nil."
        elsif first_name_clean.nil?
          positives = db.execute("SELECT * FROM entries WHERE last_name_clean LIKE ? AND credential_ = ?",
                                "#{last_name_clean}%", la_license_number)
          first_name_clean = default_value
        else
          positives = db.execute("SELECT * FROM entries WHERE first_name_clean LIKE ? AND credential_ = ?",
                                "#{first_name_clean}%", la_license_number)
          last_name_clean = default_value
        end
      end

      potentials += db.execute('select * from entries where credential_ = ?', la_license_number)
    end

    potentials += db.execute('select * from entries where (first_name_clean like ? AND last_name_clean like ?)',
                             first_name_clean, last_name_clean)
    potentials -= positives

    # This is how the reports aknowledges positives from potentials
    positives.map { |h| h['force_type'] = :positive }
    potentials.map { |h| h['force_type'] = :potential }

    results = ((positives || []) + (potentials || [])).uniq

    results = results.map do |result|
      details = 'Flagged on LA ADRA Disciplinary Actions as: ' +
                result['first_name_clean'].titleize + ' ' + result['last_name_clean'].titleize + ".\r\n"
      details += 'Action taken: ' + result['action_taken_clean'].titleize + "\r\n"
      details += 'Date of action: ' + result['date_of_action'] + "\r\n"
      details += "Date of Birth was not checked\r\n"
      details += "SSN was not checked\r\n"
      {
        row: result,
        details: details,
        force_type: result['force_type']
      }
    end
  end
end
