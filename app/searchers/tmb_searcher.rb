module TMBSearcher
  extend self

  def search_employee(employee)
    return [] unless employee.tx_license_number.present?

    return [] # TEMP: currently returning timeout errors 100% of the time

    search(employee.tx_license_number, employee.id)
  end

  def search_vendor(vendor)
    return [] unless vendor.tx_license_number.present?

    return [] # TEMP: currently returning timeout errors 100% of the time

    search(vendor.tx_license_number)
  end

  def search(tx_license_number, employee_id = 0)
    TMBScraper.new.search_scrape(tx_license_number, employee_id)
  end

  class TMBScraper < ViewStateScraper
    def base_url
      'https://public.tmb.state.tx.us/HCP_Search/searchinput.aspx'
    end

    def search_scrape(license_number, employee_id = 0)
      body = @last_response.body
      html = Nokogiri::HTML(body)

      # on first access and maybe subsequently, need to accept usage terms
      accept_button = html.css('#BodyContent_btnAccept').first
      if accept_button.present?
        # HACK: to bypass the way we set up ViewStateScraper to postback the current URL and handle a redirect
        @last_url = 'https://public.tmb.state.tx.us/HCP_Search/SearchNotice.aspx'
        response = RestClient::Request.execute(method: :post,
                                               url: 'https://public.tmb.state.tx.us/HCP_Search/SearchNotice.aspx',
                                               payload: @view_state.merge({ 'ctl00$BodyContent$btnAccept' => 'I Accept the Usage Terms' }),
                                               cookies: @last_response.cookies,
                                               headers: { content_type: 'application/x-www-form-urlencoded' },
                                               timeout: 120)
        @view_state = get_view_state(response.body)
        # File.write("tmb_accept.html", response.body)
      end

      # HACK: to bypass the way we set up ViewStateScraper to postback the current URL and handle a redirect
      @last_url = 'https://public.tmb.state.tx.us/HCP_Search/SearchInput.aspx'
      response = do_viewstate_request('https://public.tmb.state.tx.us/HCP_Search/SearchInput.aspx', {
                                        'ctl00$BodyContent$tbLastName' => '',
                                        'ctl00$BodyContent$tbFirstName' => '',
                                        'ctl00$BodyContent$tbLicense' => license_number,
                                        'ctl00$BodyContent$ddLicenseType' => 'ALL',
                                        'ctl00$BodyContent$tbCity' => '',
                                        'ctl00$BodyContent$tbZIP' => '',
                                        'ctl00$BodyContent$ddBACategory' => 'ALL',
                                        'ctl00$BodyContent$ddBADate' => '',
                                        'ctl00$BodyContent$ddBADateRangeEnd' => '',
                                        'ctl00$BodyContent$btnSearch' => 'Search'
                                      }, false, employee_id)

      html = Nokogiri::HTML(response.body)

      table = html.css('table#BodyContent_gvSearchResults').first
      # File.write("tmb_results.html", response.body)
      unless table.present? && table.css('tr').count > 1
        return [{
          row: {},
          type: :violation,
          tx_license_number: :match,
          details: 'No registration found on Texas Medical Board search - please investigate why provider is missing state registration.'
        }]
      end

      row = table.css('tr')[1]
      name_cell = row.css('td').first
      javascript_href = name_cell.css('a').first['href']
      event_target = javascript_href.match(/__doPostBack\('([0-9a-zA-Z$]+)'/)[1]

      # series of redirects to run through
      redirect_url = nil
      begin
        @last_response = RestClient::Request.execute(method: :post,
                                                     url: "https://public.tmb.state.tx.us/HCP_Search/SearchResults.aspx?LIC=#{license_number}",
                                                     payload: @view_state.merge({ '__EVENTTARGET' => event_target }),
                                                     cookies: @last_response.cookies,
                                                     headers: { content_type: 'application/x-www-form-urlencoded' },
                                                     timeout: 120)
      rescue RestClient::Found => e
        redirect_url = e.response.headers[:location]
      rescue RestClient::ExceptionWithResponse => e
        raise_flag = true

        case e.http_code
        when 404
          failed_reason = "TMBSearcher Page not found(1) https://public.tmb.state.tx.us/HCP_Search/SearchResults.aspx?LIC=#{license_number}"
        else
          failed_reason = "TMBSearcher Status code(1) #{e.http_code}, #{e.message}"
        end
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

      begin
        @last_response = RestClient::Request.execute(method: :get,
                                                     url: redirect_url,
                                                     cookies: @last_response.cookies,
                                                     timeout: 120)
      rescue RestClient::Found => e
        redirect_url = e.response.headers[:location]
      rescue RestClient::ExceptionWithResponse => e
        raise_flag = true

        case e.http_code
        when 404
          failed_reason = "#TMBSearcher Page not found(2) #{redirect_url}"
        else
          failed_reason = "#TMBSearcher Status code(2) #{e.http_code}, #{e.message}"
        end
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

      response = RestClient::Request.execute(method: :get,
                                            url: redirect_url,
                                            cookies: @last_response.cookies,
                                            timeout: 120)

      # response = do_viewstate_request('https://public.tmb.state.tx.us/HCP_Search/SearchNotice.aspx', {'__EVENTTARGET' => event_target})
      # File.write("tmb_details.html", response.body)

      html = Nokogiri::HTML(response.body)

      tables = html.css('table')

      # get last to avoid the containing table
      verified_table = tables.select do |table|
        table.text.include?('THE INFORMATION IN THIS BOX HAS BEEN VERIFIED')
      end.last

      cells = verified_table.search('td')

      status_cells = cells.to_a.select do |cell|
        text = cell.text.strip
        text.include?('Permit Status') || text.include?('Registration Status')
      end

      status_cell = status_cells.first
      # status = status_cell.text.downcase.strip.split("\n").last.strip
      status = status_cell.text.downcase \
                          .sub('permit status:', '').sub('registration status:', '') \
                          .strip
                          .gsub("\u00a0", '') # remove weird non-standard space character

      # pp status
      if ['active', 'permit issued'].include?(status)
        []
      else
        disciplinary_status_cell = cells.to_a.find do |cell|
          text = cell.text.strip
          text.include?('Disciplinary Status')
        end
        disciplinary_status = nil
        if disciplinary_status_cell.present?
          disciplinary_status = disciplinary_status_cell.text.downcase \
                                                        .sub('disciplinary status:', '') \
                                                        .strip.gsub("\u00a0", '') # remove weird non-standard space character
        end

        details = "Flagged on Texas Medical Board\n"
        details += "\n"
        details += "Matched by TX License Number #{license_number}\n"
        details += "\n"
        details += "Registration Status: #{status}\n"

        details += "Disciplinary Status: #{disciplinary_status}\n" if disciplinary_status.present?

        type = if status == 'permit terminated' || disciplinary_status == 'cancelled by board'
                 :violation
               else
                 :expiry
               end

        [{
          row: {},
          type: type,
          tx_license_number: :match,
          details: details
        }]
      end
    end
  end
end
