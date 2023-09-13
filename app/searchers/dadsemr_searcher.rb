module DADSEMRSearcher
  extend self

  def search_employee(employee)
    if employee.ssn.present? && employee.ssn.length == 9
      url = 'https://emr.dads.state.tx.us/DadsEMRWeb/searchResultsSsn.jsp'
      payload = {
        ssn: employee.ssn
      }
    else
      url = 'https://emr.dads.state.tx.us/DadsEMRWeb/searchResultsName.jsp'
      payload = {
        lastName: employee.last_name_clean,
        firstName: employee.first_name_clean
      }
    end

    # simple retry mechanism with backoff
    response = nil

    begin
      with_retries(max_tries: 4, base_sleep_seconds: 2, max_sleep_seconds: 5) do
        response = RestClient::Request.execute(method: :post,
                                               url: url,
                                               payload: payload,
                                               timeout: 120)
      end
    rescue RestClient::ExceptionWithResponse => e
      raise_flag = true

      case e.http_code
      when 302
        failed_reason = "DADSEMRSearcher Unavailable Redirect URL #{url}"
      else
        failed_reason = "DADSEMRSearcher Status code #{e.http_code}, #{e.message}"
      end
      http_code = e.http_code || nil
      if raise_flag
        raise "FailedReason: #{failed_reason}\n" +
              "Response headers: #{e.response&.headers}\n" +
              "Response body: #{e.response&.body}\n" +
              "FailedEmployeeID: #{employee.id}\n" +
              "StatusCode: #{http_code}\n" +
              "FailedReasonEnd"
      end
    end

    html = Nokogiri::HTML(response&.body)

    cols = %w[ssn_last_4 name unemployable nar_status certification_expiration_date
              nar_active_unemployable nar_facility_type_where_active_unemployable
              mar_status permit_expiration_date
              mar_active_unemployable mar_facility_type_where_active_unemployable
              listed_on_emr registry_enter_date]

    col_labels = ['Last SSN', 'Full Name', 'Unemployable?', 'NAR Status', 'Certification Expiration Date',
                  'NAR: Active, Unemployable', 'NAR: Facility Type where Active Unemployable',
                  'MAR Status', 'Permit Expiration Date', 'MAR: Active, Unemployable',
                  'MAR: Facility Type where Active Unemployable', 'Listed on the EMR',
                  'Registry Enter Date']
    rows = html.css('table#searchResults tbody tr').map do |tr|
      Hash[cols.zip(tr.css('td').map(&:text))]
    end

    # filter out any entries that do not match last 4 of employee's ssn, IF employee's SSN was specified.
    # this ensures we don't report any more false positives than we need to.
    employee_has_ssn = employee.ssn.present? && employee.ssn.length == 9
    rows = rows.select { |row| employee.ssn.last(4) == row['ssn_last_4'] } if employee_has_ssn

    # write details about why each row was flagged
    rows.map! do |row|
      has_violation = row['unemployable'].downcase.strip == 'yes' ||
                      row['mar_active_unemployable'].downcase.strip == 'yes'

      has_expiry = false

      if row['certification_expiration_date'].strip.present?
        nurse_expiry_date = Date.strptime(row['certification_expiration_date'].strip, '%m/%d/%Y')
        has_expiry ||= Date.today >= nurse_expiry_date
      end

      if row['permit_expiration_date'].strip.present?
        permit_expiration_date = Date.strptime(row['permit_expiration_date'].strip, '%m/%d/%Y')
        has_expiry ||= Date.today >= permit_expiration_date
      end

      has_expiry ||= (row['listed_on_emr'].downcase.strip == 'yes')
      has_expiry ||= (row['mar_status'].downcase.strip == 'lapsed')

      next nil unless has_violation || has_expiry

      result = { row: row }
      result[:type] = has_violation ? :violation : :expiry

      details = 'Matched on Texas Department of Aging and Disability Services Employee Misconduct Registry as:'
      details += "\n"
      details += row['name']
      details += "\n"

      details += 'Please note this does not necessarily mean that this employee is sanctioned. Please check the specifics listed below.'
      details += "\n"

      (2...cols.count).each do |col_index|
        label = col_labels[col_index]
        next if label.nil?

        col = cols[col_index]
        next if col.nil?

        val = row[col]
        next unless val.present?

        details += "#{label}: #{val}"
        details += "\n"
      end

      if employee_has_ssn && employee.ssn.last(4) == row['ssn_last_4']
        details += 'Matched by Last 4 Digits of SSN (DOB not checked)'
        details += "\n"

        result[:ssn] = :match
        result[:dob] = :not_checked
      else
        details += 'Date of Birth was not checked'
        details += "\n"
        details += 'SSN was not checked'
        details += "\n"

        result[:ssn] = :not_checked
        result[:dob] = :not_checked
      end

      result[:details] = details

      # row['name'] is in the format LAST, FIRST
      result[:first] = row['name'].split(', ').last
      result[:last] = row['name'].split(', ').first

      result
    end

    rows.compact
  end
end
