require 'csv'

module OFACSearcher
  include DatabaseSearcher
  extend self

  def db_name
    'OFAC'
  end

  def db_refresh_url
    'https://www.treasury.gov/ofac/downloads/sdn.xml'
  end

  def search_employee(employee)
    add_details_to_results(search(employee.last_name_clean, employee.first_name_clean))
  end

  def search_vendor(vendor)
    add_details_to_results(search(vendor.last_name_or_entity_name_clean, vendor.first_name_clean))
  end

  def add_details_to_results(results)
    results.each do |result|
      row = result[:row]
      details = 'Flagged on OFAC as: '

      details += if row['first_name'].present?
                   "#{row['last_name']}, #{row['first_name']}\n"
                 else
                   "#{row['last_name']}\n"
                 end

      details += "Type: #{row['type']}\n" if row['type'].present?

      details += "Program(s): #{row['programs']}\n" if row['programs'].present?

      details += "Address: #{row['address']}\n" if row['address'].present?

      details += 'Date of Birth was not checked'
      details += "\n"

      details += 'SSN was not checked'
      details += "\n"

      result[:details] = details
      result[:first] = row['first_name']
      result[:last] = row['last_name']
    end

    results
  end

  def search(last_name_clean, first_name_clean)
    results = if first_name_clean.present?
                rows = db.execute('select * from entries where first_name_clean like ? and last_name_clean like ?',
                                  [first_name_clean + '%', last_name_clean])
                rows.select do |row|
                  ApplicationRecord.do_names_match?(last_name_clean, row['last_name_clean']) &&
                    ApplicationRecord.do_names_match?(first_name_clean, row['first_name_clean'])
                end
              else
                rows = db.execute('select * from entries where last_name_clean like ?', [last_name_clean])
                rows.select do |row|
                  ApplicationRecord.do_names_match?(last_name_clean, row['last_name_clean'])
                end
              end

    results.map do |result|
      {
        row: result,
        dob: :not_checked,
        ssn: :not_checked
      }
    end
  end

  # def search(name)
  #   results = OFACScraper.new.search_scrape(name)
  #                        .map { |row| { row: row } }
  #
  #   results.each do |result|
  #     row = result[:row]
  #     details = "Flagged on OFAC as: #{row['Name']}\n"
  #
  #     row.each do |key, value|
  #       details += "#{key}: #{value}\n"
  #     end
  #
  #     result[:details] = details
  #   end
  #
  #   results
  # end

  # class OFACScraper < ViewStateScraper
  #   def base_url
  #     'https://sanctionssearch.ofac.treas.gov/'
  #   end
  #
  #   def search_scrape(entity_name)
  #     name_score = 96 # out of 100, sort of a holistic name similarity score for searches
  #
  #     params = {
  #       'ctl00_ctl03_HiddenField' => ';;AjaxControlToolkit, Version=3.5.40412.0, Culture=neutral, PublicKeyToken=28f01b0e84b6d53e:en-US:1547e793-5b7e-48fe-8490-03a375b13a33:475a4ef5:5546a2b:d2e10b12:497ef277:effe2a26',
  #       'ctl00$MainContent$ddlType' => '',
  #       'ctl00$MainContent$txtAddress' => '',
  #       'ctl00$MainContent$txtLastName' => entity_name,
  #       'ctl00$MainContent$txtCity' => '',
  #       'ctl00$MainContent$txtID' => '',
  #       'ctl00$MainContent$txtState' => '',
  #       'ctl00$MainContent$lstPrograms' => '',
  #       'ctl00$MainContent$ddlCountry' => '',
  #       'ctl00$MainContent$ddlList' => '',
  #       'ctl00$MainContent$Slider1' => name_score,
  #       'ctl00$MainContent$Slider1_Boundcontrol' => name_score,
  #       'ctl00$MainContent$btnSearch' => 'Search'
  #     }
  #
  #     response = do_viewstate_request(base_url, params)
  #
  #     body = response.body
  #
  #     html = Nokogiri::HTML(body)
  #
  #     rows = html.css('div#scrollResults tr').to_a
  #
  #     rows.map do |row|
  #       keys = ['Name', 'Address', 'Type', 'Program(s)', 'List', 'Name Match %']
  #       values = row.css('td').to_a
  #                   .map(&:text)
  #                   .map { |str| str == '&nbsp;' ? '' : str } # coerce &nbsp; placeholders to empty strings
  #
  #       Hash[keys.zip(values)]
  #     end
  #   end
  # end
end
