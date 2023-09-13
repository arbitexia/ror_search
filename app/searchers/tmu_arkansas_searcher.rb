module TmuArkansasSearcher
  extend self

  def search_employee(employee)
    search_by_ssn(employee.ssn, employee.id)
  end

  def search_vendor(vendor)
    search_by_ssn(vendor.ein)
  end

  def search_by_ssn(ssn, employee_id = 0)
    return [] unless ssn.present? && ssn.length == 9

    puts "TMU: checking SSN/EIN: #{ssn}"

    url = 'https://ar.tmuniverse.com/search?search_type=SSN&q='
    url += URI.encode_www_form_component(ssn[0..2])
    url += '-' + URI.encode_www_form_component(ssn[3..4])
    url += '-' + URI.encode_www_form_component(ssn[5..8])

    #url = "https://ar.tmuniverse.com/search?search_type=Misconduct&q=John+Davish" example url for misconduct

    response = fetch_page(url, employee_id)

    search_result = Nokogiri::HTML(response.body)

    return [] if search_result.search('p:contains("Sorry, no matches found")').present?
    return [] unless search_result.search('p:contains("Found 1 matching results")').present?     # it shouldn't really find more than 1 person with the same SSN, but just in case
    return [] if search_result.search('span:contains("No history of misconduct")').present?

    results = []

    full_name = search_result.css('.block.pb-2.text-lg.font-heading').first.text.split("\n")[1].strip
    first_name = full_name.split(',').second.strip
    last_name = full_name.split(',').first.strip

    details_result = Nokogiri::HTML(fetch_page(search_result.search('a.group.p-4.shadow.rounded')[0]['href'], employee_id))
    details_result.search('table.table-striped.text-gray-700 tbody tr').each do |tr|
      type = tr.search('td')[0].text.strip
      verified_at = tr.search('td')[1].text.strip
      complaint_date = tr.search('td')[2].text.strip
      details = "Flagged on TMU Arkansas Misconduct Registry" + "\r\n"
      details += "Type: #{type}" + "\r\n"
      details += "Verified at: #{verified_at}" + "\r\n"
      details += "Complaint date: #{complaint_date}"
      results << {
        details: details,
        first: first_name,
        last: last_name,
        type: :violation
      }
    end
    results
  end

  def fetch_page(url, employee_id)
    response = nil
    begin
      with_retries(max_tries: 2, base_sleep_seconds: 2, max_sleep_seconds: 5) do
        response = RestClient::Request.execute(method: :get,
                                              url: url,
                                              timeout: 120)
      end
    rescue RestClient::ExceptionWithResponse => e
      raise_flag = true

      case e.http_code
      when 429
        failed_reason = "TmuArkansasSearcher Too Many Requests to #{url}\nPlease "
      else
        failed_reason = "TmuArkansasSearcher Status code #{e.http_code}, #{e.message}"
      end
      http_code = e.http_code || nil
      if raise_flag
        raise "FailedReason: #{failed_reason}\n" +
              "Response headers: #{e.response&.headers}\n" +
              "Response body: #{e.response&.body}" +
              "FailedEmployeeID: #{employee_id}\n" +
              "StatusCode: #{http_code}\n" +
              "FailedReasonEnd"
      end
    rescue StandardError => e
      logger.error "TmuArkansasSearcher: #{e.message}"
      http_code = e.http_code || nil
      raise "FailedReason: #{e.message}\n" +
            "Response headers: \n" +
            "Response body: \n" +
            "FailedEmployeeID: #{employee_id}\n" +
            "StatusCode: #{http_code}\n" +
            "FailedReasonEnd"
    end

    sleep 5
    response
  end
end
