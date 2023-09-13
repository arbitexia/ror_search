require 'rubyXL'
require 'csv'

# Mississippi Medicaid provides a human-tailored Excel file, so we first download this + parse it into a CSV,
# then that CSV is read in using the standard DatabaseSearcher logic.
module MSMedicaidSearcher
  include DatabaseSearcher
  extend self

  def db_name
    'MSMedicaid'
  end

  def db_refresh_url
    Rails.root.join('data', 'msmedicaid.csv')
  end

  def download_latest_list
    # find latest file
    base_url = 'https://medicaid.ms.gov'
    page_url = base_url + '/providers/provider-terminations/'
    response = RestClient::Request.execute(method: :get,
                                          url: page_url,
                                          timeout: 120)
    html = Nokogiri::HTML(response.body)

    link = html.css('a').select { |a| a.text == 'Sanctioned Provider List' }.first
    xlsx_url = link['href']
    xlsx_url = base_url + xlsx_url if xlsx_url.start_with?('/')

    xlsx_filename = Rails.root.join('data', 'msmedicaid.xlsx')
    open(xlsx_url) do |url_file|
      File.binwrite(xlsx_filename, url_file.read)
    end

    workbook = RubyXL::Parser.parse(xlsx_filename)
    worksheet = workbook[0]

    column_names = []
    rows = []
    found_header_row = false
    worksheet.each do |row|
      if found_header_row
        # common case: we have column names already.

        unless row.cells.first.value.is_a?(Integer)
          # dead row - these commonly appear at end of file
          next
        end

        values = row.cells.map(&:value)
        values = values[1...values.count] # first column is row number, so drop that
        values.map! do |value|
          if value.is_a? DateTime
            value.to_date.to_s
          else
            value.to_s
          end
        end

        rows << values
      elsif row.cells[1].value.nil?
        # initial case: we are looking for column names.
        next
      # still looking...first few rows have nothing in cells
      else
        # this is the header row
        found_header_row = true
        column_names = row.cells.map(&:value).compact
      end
    end

    # now we can write out column names and rows
    csv_string = CSV.generate do |csv|
      csv << column_names
      rows.each do |row|
        csv << row
      end
    end

    File.write(db_refresh_url, csv_string)
  end

  def search_employee(employee)
    results = search(employee.last_name_clean, employee.first_name_clean, employee.middle_name_clean, nil)

    add_details_to_results(results, was_employee_search: true)
    results
  end

  def search_vendor(vendor)
    results = search(vendor.last_name_or_entity_name_clean, vendor.first_name_clean, vendor.middle_name_clean,
                     vendor.npi)

    add_details_to_results(results, was_employee_search: false)
    results
  end

  def add_details_to_results(results, was_employee_search: false)
    results&.each do |result|
      row = result[:row]

      details = 'Flagged on Mississippi Medicaid Exclusions List as: ' + row['provider_name']

      details += "\n"

      if was_employee_search
        details += 'Date of Birth was not checked'
        details += "\n"
        details += 'SSN was not checked'
        details += "\n"
      end

      details += "Termination reason: #{row['termination_reason']}\n" if row['termination_reason'].present?

      if row['termination_effective_date'].present?
        details += "Termination effective date: #{row['termination_effective_date']}\n"
      end

      details += "Exclusion period: #{row['exclusion_period']}\n" if row['exclusion_period'].present?

      details += "Sanction type: #{row['sanction_type']}\n" if row['sanction_type'].present?

      if result[:npi] == :match
        details += 'NPI was checked and matched'
        details += "\n"
      elsif result[:npi] == :no_match
        details += 'NPI was checked and did not match NPI on record'
        details += "\n"
      elsif row['npi'].present?
        details += "NPI: #{row['npi']}\n"
      end

      result[:details] ||= details
      result[:details] += "\n"

      result[:first] = row['first']
      result[:last] = row['last']
      result[:middle] = row['middle']
    end
  end

  def search(last_name_clean, first_name_clean, middle_name_clean, npi)
    search_string = "#{last_name_clean} #{first_name_clean}%"

    results =   begin
                  if first_name_clean.present?
                  # Execute the query
                    rows = db.execute('select * from entries where provider_name_clean like ?', [search_string])
                    rows.select do |row|
                      external_last_name = row['provider_name'].split(',')[0]
                      external_first_and_middle_name = row['provider_name'].split(',')[1]
                      ApplicationRecord.do_names_match?(last_name_clean,
                                                        Vendor.sanitize_name(external_last_name)) && ApplicationRecord.do_first_and_middle_names_match?(first_name_clean,
                                                                                                                                                        middle_name_clean, Vendor.sanitize_name(external_first_and_middle_name))
                    end
                  elsif last_name_clean.present?
                    entity_name_clean = last_name_clean
                    rows = db.execute('select * from entries where provider_name_clean like ?', [entity_name_clean + '%'])
                    rows.select do |row|
                      ApplicationRecord.do_names_match?(entity_name_clean, row['provider_name_clean'])
                    end
                  end
                rescue SQLite3::SQLException => e
                  if e.message.include?('no such table')
                    puts "The 'entries' does not exist."
                  else
                    puts "An error occurred: #{e}"
                  end
                end

    results = results&.uniq&.map do |result|
      {
        row: result
      }
    end

    results&.each do |result|
      found_npi = result[:row]['npi']
      result[:npi] = if found_npi.present?
                       found_npi.to_s == npi.to_s ? :match : :no_match
                     else
                       :not_checked
                     end
    end

    # we filter out no-match NPIs
    results&.reject { |result| result[:npi] == :no_match }
  end
end
