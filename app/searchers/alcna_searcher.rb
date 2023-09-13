module ALCNASearcher
  extend self

  def search_employee(employee)
    return [] if employee.ssn.nil? || employee.ssn.empty?

    scraper = ALCNAScraper.new
    rows = scraper.search_scrape(employee.ssn, employee.id)

    rows.map do |row|
      # write details about why each row was flagged
      result = { row: row }

      details = 'Flagged on Alabama CNA as: '
      details += row['last_name'].to_s
      details += ', '
      details += row['first_name'].to_s
      details += "\n"

      if row['expiration_status'].present?
        details += "Expiration Status:\n"
        details += row['expiration_status'].gsub('<br>', "\n")
      end

      details += 'Matched by SSN'
      details += "\n"

      result[:ssn] = :match
      result[:dob] = :not_checked

      result[:details] = details
      result[:first] = row['first_name']
      result[:last] = row['last_name']

      result
    end
  end

  class ALCNAScraper < ViewStateScraper
    def base_url
      'https://dph1.adph.state.al.us/NurseAideRegistry'
    end

    # search_type: CNA or ALCNA
    # both return first_name and last_name parsed from the respective name column in each result
    # CNA additionally returns {certification_number: numeric, certified_from_to: "mm/dd/yyyy - mm/dd/yyyy", original_certification: mm/dd/yyyy, status: Certified|Not Certified|Call CNA Registry, retest_required_by: mm/dd/yyyy (optional)}
    # ALCNA additionally returns {registration_number: numeric, original_registration: mm/dd/yyyy (optional), status: "Finding mm/dd/yy", retest_required_by: ? (blank?)}
    def search_scrape(ssn, employee_id = 0)
      url = @last_response&.request.url
      do_viewstate_request(url, {}, false, employee_id)

      params = {
        'ctl00$MainContent$TextBoxSSN' => ssn.gsub(/(\d{3})(\d{2})(\d{4})/, '\1-\2-\3'), # add dashes to ssn
        'ctl00$MainContent$MaskedEditExtenderSSN_ClientState' => '',
        'ctl00$MainContent$ButtonSubmit' => 'Search'
      }

      # simple retry mechanism with backoff
      response = nil
      with_retries(max_tries: 4, base_sleep_seconds: 2, max_sleep_seconds: 5) do
        response = do_viewstate_request(url, params, false, employee_id)
      end

      body = response.body
      html = Nokogiri::HTML(body)

      # File.write('results.html', body)
      # `open results.html`

      if body.include?('is not found in registry.')
        # no search results
        []
      else
        # scrape the table into a hash
        row = {}
        html.css('table#MainContent_Table1 tr').each do |tr|
          cells = tr.css('td').to_a
          next if cells.count != 2

          property = cells[0].text.strip.downcase.gsub(' ', '_')
          value = cells[1].text.strip

          value = value.sub('(Wrong/misspelled name? Click here)', '').strip if property == 'last_name'

          row[property] = value
        end

        if row['adverse_finding'] && row['adverse_finding'].strip.downcase == 'none'
          []
        else
          [row]
        end
      end
    end
  end
end
