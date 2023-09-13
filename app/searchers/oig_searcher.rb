require 'csv'

module OIGSearcher
  include DatabaseSearcher
  extend self

  def db_name
    'OIG'
  end

  def db_refresh_url
    'https://oig.hhs.gov/exclusions/downloadables/UPDATED.csv'
  end

  def search_employee(employee)
    results = search(employee.last_name_clean, employee.first_name_clean, employee.middle_name_clean, employee.dob,
                     employee.ssn)

    results.select! do |result|
      (result[:dob] == :not_checked && result[:ssn] == :not_checked) || result[:dob] == :match || result[:ssn] == :match
    end

    results.reject! { |result| result[:ssn] == :no_match }

    results.each do |result|
      row = result[:row]
      details = 'Flagged on OIG as: '
      details += row['lastname']
      details += ', '
      details += row['firstname']
      details += ' '
      details += row['midname']
      details += "\n"

      details += "Exclusion type: #{row['excltype']}"
      details += "\n"

      details += "Exclusion date: #{row['excldate']}"
      details += "\n"

      if result[:dob] == :not_checked
        details += 'Date of Birth was not checked'
        details += "\n"
      elsif result[:dob] == :no_match
        details += 'Note: Date of Birth was checked and did not match DOB on record'
        details += "\n"
      end

      if result[:ssn] == :not_checked
        details += 'SSN was not checked'
        details += "\n"
      elsif result[:ssn] == :no_match
        details += 'Note: SSN was checked and did not match SSN on record'
        details += "\n"
      end

      result[:details] = details
      result[:first] = row['firstname']
      result[:last] = row['lastname']
      result[:middle] = row['midname']
    end
  end

  def search_vendor(vendor)
    results = search(vendor.last_name_or_entity_name_clean, vendor.first_name_clean, vendor.middle_name_clean, nil,
                     vendor.ein, npi: vendor.npi)

    results.each do |result|
      row = result[:row]
      details = 'Flagged on OIG as: '
      if row['busname'].present?
        details += row['busname']
      else
        details += row['lastname']
        details += ', '
        details += row['firstname']
        details += ' '
        details += row['midname']
      end
      details += "\n"

      if result[:npi] == :match
        details += 'NPI was checked and matched'
        details += "\n"
      end

      if result[:ssn] == :not_checked
        details += 'EIN was not checked'
        details += "\n"
      elsif result[:ssn] == :no_match
        details += 'Note: EIN was checked and did not match EIN on record'
        details += "\n"
      end

      details += "Exclusion type: #{row['excltype']}"
      details += "\n"

      details += "Exclusion date: #{row['excldate']}"
      details += "\n"

      result[:details] = details
    end

    results
  end

  def search(last_name_clean, first_name_clean = nil, middle_name_clean = nil, dob = nil, ssn = nil, npi: nil)
    results = if npi.present?
                rows = db.execute('select * from entries where npi = ?', [npi])
                rows
              elsif first_name_clean.present?
                rows = db.execute('select * from entries where firstname_clean like ? and lastname_clean like ?',
                                  [first_name_clean + '%', last_name_clean + '%'])
                rows.select do |row|
                  ApplicationRecord.do_names_match?(last_name_clean, row['lastname_clean']) &&
                    ApplicationRecord.do_names_match?(first_name_clean, row['firstname_clean'])
                end
              elsif last_name_clean.present?
                entity_name_clean = last_name_clean
                rows = db.execute('select * from entries where busname_clean like ?', [entity_name_clean + '%'])
                rows.select do |row|
                  ApplicationRecord.do_names_match?(entity_name_clean, row['busname_clean'])
                end
              end

    results = results.select do |result|
      if result['midname_clean'].present? && middle_name_clean.present?
        result_middle = Employee.sanitize_name(result['midname_clean'])
        if result_middle.length == 1 || middle_name_clean.length == 1
          # when middle name specified on both, permit when middle initial matches
          result_middle[0] == middle_name_clean[0]
        else
          # ... unless both were fully specified middle names... then remove spaces and check them against each other for a potential match
          result_middle.gsub(/\s+/, '') == middle_name_clean.gsub(/\s+/, '')
        end
      else
        true # when middle name not specified on both, permit any middle name
      end
    end.map do |result|
      {
        row: result,
        dob: :not_checked,
        ssn: :not_checked
      }
    end

    run_dob_match(results, dob) if dob.present?

    if ssn.present?
      puts "OIG: checking SSN/EIN: #{ssn}"

      begin
        run_ssn_match(results, ssn)
        puts 'OIG: checked SSN/EIN'
      rescue StandardError => e
        warn e
        # sometimes OIG seems to go down or rate limit us, so if ssn match fails due to a request error,
        # we'll just hope DOB got checked or else report a potential match.
        # can't afford this to cause report failues
      end
    end

    if npi.present?
      results.each do |result|
        if npi.present?
          result[:npi] = result[:row]['npi'] == npi ? :match : :no_match
        end
      end
    end

    # we filter out no-match NPIs
    results.reject { |result| result[:npi] == :no_match }
  end

  # processes a result set to determine whether the DOB matches our requested DOB.
  def run_dob_match(results, dob)
    dob_string = if dob.is_a?(Date)
                   dob.strftime('%Y%m%d')
                 else
                   dob
                 end

    results.each do |result|
      row = result[:row]

      next unless row['dob'].present?

      result[:dob] = if row['dob'] == dob_string
                       :match
                     else
                       :no_match
                     end
    end
  end

  # processes a result set to determine whether any matching SSN matches our requested SSN.
  # this involves scraping the OIG website with separate requests.
  def run_ssn_match(results, ssn)
    unless ssn.to_s.length == 9
      warn "ssn must be 9 digits: was #{ssn}"
      return
    end
    results.each do |result|
      run_single_ssn_match(result, ssn)
    end
  end

  def run_single_ssn_match(result, ssn)
    scraper = OIGScraper.new

    ssn_checked = false
    ssn_matches = false
    loop do
      event_target = scraper.search_scrape(result[:row]['lastname'], result[:row]['firstname'], result[:row])
      puts "event_target: #{event_target}"
      break if event_target.nil?

      ssn_verify_result = scraper.verify_scrape(ssn, result[:row]['dob'], event_target)
      puts
      puts "verify result: #{ssn_verify_result}"
      puts
      ssn_checked = true unless ssn_verify_result.nil?

      # noinspection RubySimplifyBooleanInspection
      ssn_matches = true if ssn_verify_result == true
    end

    result[:ssn] = if ssn_checked
                     if ssn_matches
                       :match
                     else
                       :no_match
                     end
                   else
                     :not_checked
                   end

    puts "found #{result[:ssn]}"
  end

  # TODO: nomenclature: all of verify_scrape
  class OIGScraper < ViewStateScraper
    def base_url
      'https://exclusions.oig.hhs.gov/default.aspx'
    end

    def search_scrape(last_name, first_name, sql_row, employee_id = 0)
      response = if @last_url == 'https://exclusions.oig.hhs.gov/SearchResults.aspx'
                   # do not re-run a search if our last request was a search -- this comes up when verifying multiple results
                   @last_response
                 else
                   do_viewstate_request('https://exclusions.oig.hhs.gov/SearchResults.aspx', {
                                          'ctl00$cpExclusions$txtSPFirstName' => first_name,
                                          'ctl00$cpExclusions$txtSPLastName' => last_name,
                                          'ctl00$cpExclusions$ibSearchSP.x' => 27,
                                          'ctl00$cpExclusions$ibSearchSP.y' => 11
                                        }, false, employee_id)
                 end

      body = response.body

      html = Nokogiri::HTML(body)

      rows = html.css('table.leie_search_results tr').to_a
      rows.delete(rows.first) # header row

      rows.each.with_index do |row, index|
        next if index < @offset

        if rows_match?(row, sql_row)
          @offset = index + 1
          link = row.css('a').find { |a| a.text.strip.downcase == 'verify' }
          return extract_state(link['href']) if link.present?
        end
      end
      nil
    end

    def rows_match?(table_row, sql_row)
      values = table_row.css('td').map(&:text).map(&:strip).map { |val| val.gsub(/\W/, '') }

      matchers = {
        'lastname' => values[0],
        'firstname' => values[1],
        'excltype' => values[5]
      }

      matchers['middlename'] = values[2] if sql_row['middlename'].present?

      matchers.inject(true) do |all_match, pair|
        key, value = pair
        sql_value = sql_row[key].to_s.strip.downcase.gsub(/\W/, '')
        matches = sql_value == value.to_s.strip.downcase
        puts "#{key}=>#{matches} (#{sql_value} ?= #{value.to_s.strip.downcase})"
        all_match && matches
      end
    end

    def extract_state(javascript_href)
      javascript_href.match(/__doPostBack\('([0-9a-zA-Z$]+)'/)[1]
    end

    def verify_scrape(correct_ssn, correct_dob, verification_state, employee_id = 0)
      verification_response = do_viewstate_request('https://exclusions.oig.hhs.gov/Verify.aspx',
                                                   '__EVENTTARGET' => verification_state)

      # verification response contains details about the given person

      html = Nokogiri::HTML(verification_response.body)
      dob = html.css('acronym[title="Date of Birth"]').first.parent.parent.css('td').text # 01/01/1900
      month, day, year = dob.split('/')
      formatted_dob = "#{year}#{month}#{day}"

      puts "#{formatted_dob} =?= #{correct_dob}"
      return nil unless formatted_dob == correct_dob

      params = {
        'ctl00$ScriptManager1' => 'ctl00$ScriptManager1|ctl00$cpExclusions$ibtnVerify',
        '__ASYNCPOST' => true,
        '__SCROLLPOSITIONX' => 0,
        '__SCROLLPOSITIONY' => 0,
        'ctl00$cpExclusions$txtSSN' => correct_ssn,
        'ctl00$cpExclusions$ibtnVerify.x' => 27,
        'ctl00$cpExclusions$ibtnVerify.y' => 17
      }
      p params

      # ssn_verify_response = do_viewstate_request('https://exclusions.oig.hhs.gov/Verify.aspx', params)
      ssn_verify_response = RestClient::Request.execute(method: :post,
                                                       url: 'https://exclusions.oig.hhs.gov/Verify.aspx',
                                                       payload: @view_state.merge(params),
                                                       headers: { user_agent: 'Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2228.0 Safari/537.36' },
                                                       cookies: @last_response.cookies,
                                                       timeout: 120)
      @last_response = ssn_verify_response

      no_ssn_match = ssn_verify_response.body.include?('Images/verify-no-match.png')
      ssn_match = !no_ssn_match

      raise "No MATCH in #{ssn_verify_response.body}" unless ssn_verify_response.body.include?('MATCH')

      @view_state = grab_view_state_from_asyncpost(ssn_verify_response.body)

      # do stuff
      back_view_state = 'ctl00$cpExclusions$lbBackToSearch'
      do_viewstate_request(
        'https://exclusions.oig.hhs.gov/SearchResults.aspx', 
        '__EVENTTARGET' => back_view_state
      )
      verification_response.body

      ssn_match
    end
  end
end
