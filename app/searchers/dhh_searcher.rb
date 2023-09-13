require 'csv'

module DHHSearcher
  include DatabaseSearcher
  extend self

  def db_name
    'DHH'
  end

  def db_refresh_url
    'https://adverseactions.ldh.la.gov/SelSearch/SelSearch/GetCsv'
  end

  def search_employee(employee)
    if employee.ssn.present?
      results = search_ssn(employee.ssn, employee.id)
    else
      results = search(employee.last_name_clean, employee.first_name_clean, employee.middle_name_clean, employee.dob,
                       nil)
      # if dob was present and did not match what we have on file, and we didnt check ssn, assume no match
      results.reject! do |result|
        result[:dob] == :no_match
      end
    end

    results.each do |result|
      row = result[:row]
      details = 'Flagged on Louisiana LDH Adverse Actions List as: '
      if row['name']
        details += row['name']
      else
        details += row['last_name_or_entity_name']
        details += ', '
        details += row['first_name']
      end
      details += "\n"

      details = add_exclusion_info(details, row)

      if result[:ssn] == :match
        details += 'Matched by SSN'
        details += "\n"
      else
        if result[:dob] == :not_checked
          details += 'Date of Birth was not checked'
          details += "\n"
        elsif result[:dob] == :no_match
          details += 'Note: Date of Birth was checked and did not match DOB on record'
          details += "\n"
        end

        details += 'SSN was not checked'
        details += "\n"
      end

      result[:details] = details
      result[:first] = row['first_name']
      result[:last] = row['last_name_or_entity_name']
    end
  end

  def search_vendor(vendor)
    results = if vendor.ein.present?
                search_ssn(vendor.ein)
              else
                search(vendor.last_name_or_entity_name_clean, vendor.first_name_clean, vendor.middle_name_clean, nil,
                       vendor.npi)
              end

    results.each do |result|
      row = result[:row]
      details = 'Flagged on Louisiana LDH Adverse Actions List as: '
      details += row['last_name_or_entity_name']
      if row['first_name'].present?
        details += ', '
        details += row['first_name']
      end
      details += "\n"

      details = add_exclusion_info(details, row)

      if result[:npi] == :match
        details += 'NPI was checked and matched'
        details += "\n"
      end

      if result[:ssn] == :match
        details += 'Matched by EIN'
        details += "\n"
      else
        details += 'EIN was not checked'
        details += "\n"
      end

      result[:details] = details
    end

    results
  end

  def add_exclusion_info(details, row)
    if row['type_of_exclusion'].present?
      details += "Type of Exclusion: #{row['type_of_exclusion']}"
      details += "\n"
    end

    if row['reason_for_exclusion'].present?
      details += "Reason for Exclusion: #{row['reason_for_exclusion']}"
      details += "\n"
    end

    if row['reason_for_termination'].present?
      details += "Reason for Termination: #{row['reason_for_termination']}"
      details += "\n"
    end

    if row['effective_date'].present?
      details += "Effective date: #{row['effective_date']}"
      details += "\n"
    end

    if row['period_of_exclusion'].present?
      details += "Period of Exclusion: #{row['period_of_exclusion']}"
      details += "\n"
    end

    if row['period_of_enrollment_prohibition'].present?
      details += "Period of Enrollment Prohibition: #{row['period_of_enrollment_prohibition']}"
      details += "\n"
    end

    if row['reinstate'].present?
      details += "Reinstate: #{row['reinstate']}"
      details += "\n"
    end

    details
  end

  def search(last_name_clean, first_name_clean, middle_name_clean, dob, npi)
    results = if npi.present?
                rows = db.execute('select * from entries where npi = ?', [npi])
                rows
              elsif first_name_clean.present?
                rows = db.execute(
                  'select * from entries where first_name_clean like ? and last_name_or_entity_name_clean like ?', [
                    first_name_clean + '%', last_name_clean + '%'
                  ]
                )
                rows.select do |row|
                  ApplicationRecord.do_names_match?(last_name_clean, row['last_name_or_entity_name_clean']) &&
                    ApplicationRecord.do_first_and_middle_names_match?(first_name_clean, middle_name_clean,
                                                                       row['first_name_clean'])
                end
              else
                entity_name_clean = last_name_clean
                rows = db.execute('select * from entries where last_name_or_entity_name like ?',
                                  [entity_name_clean + '%'])
                rows.select do |row|
                  ApplicationRecord.do_names_match?(entity_name_clean, row['last_name_or_entity_name_clean'])
                end
              end

    results = results.map do |result|
      {
        row: result,
        dob: :not_checked
      }
    end

    run_dob_match(results, dob) if dob.present?

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
                   dob.strftime("#{dob.month}/#{dob.day}/#{dob.year} 12:00:00 AM")
                 else
                   dob
                 end

    results.each do |result|
      row = result[:row]

      next unless row['birthdate'].present?

      result[:dob] = if row['birthdate'] == dob_string
                       :match
                     else
                       :no_match
                     end
    end
  end

  def search_ssn(ssn, employee_id = 0)
    ssn_with_dashes = ssn.gsub(/(\d{3})(\d{2})(\d{4})/, '\1-\2-\3')

    url = "https://adverseactions.ldh.la.gov/SelSearch/SelSearch/_Grid?firstNames=&lastNames=&searchSsn=#{ssn_with_dashes}&X-Requested-With=XMLHttpRequest"
    headers = {
      firstNames: '',
      lastNames: '',
      searchSsn: ssn_with_dashes,
      'Referer': 'https://adverseactions.ldh.la.gov/SelSearch',
      'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/87.0.4280.141 Safari/537.36',
      'X-Requested-With': 'XMLHttpRequest'
    }

    response = nil
    with_retries(max_tries: 4, base_sleep_seconds: 2, max_sleep_seconds: 5) do
      begin
        response = RestClient::Request.execute(method: :get,
                                               url: url,
                                               headers: headers,
                                               timeout: 120)
      rescue RestClient::ExceptionWithResponse => e
        raise_flag = true

        failed_reason = "DHHSearcher Status code #{e.http_code}, #{e.message}, #{url}"
        http_code = e.http_code || nil
        if raise_flag
          raise "FailedReason: #{failed_reason}\n" +
                "Response headers: #{e.response&.headers}\n" +
                "Response body: #{e.response&.body}\n" +
                "FailedEmployeeID: #{employee_id}\n" +
                "StatusCode: #{http_code}\n" +
                "FailedReasonEnd"
        end
      end
    end

    body = response.body
    html = Nokogiri::HTML(body)

    return [] if body.include?('Your search did not return any results. Please try again.')

    html.css('#newGrid table.webGrid tr').map do |tr|
      next nil if tr.css('td').count == 0

      _, name, type, reason_for_exclusion, reason_for_termination, effective_date, period_of_exclusion, period_of_enrollment_prohibition, program_office = tr.css('td').map(&:text)

      {
        row: {
          'name' => name,
          'type_of_exclusion' => type,
          'reason_for_exclusion' => reason_for_exclusion,
          'reason_for_termination' => reason_for_termination,
          'effective_date' => effective_date,
          'period_of_exclusion' => period_of_exclusion,
          'period_of_enrollment_prohibition' => period_of_enrollment_prohibition,
          'program_office' => program_office
        },
        ssn: :match,
        dob: :not_checked
      }
    end.compact
  end
end
