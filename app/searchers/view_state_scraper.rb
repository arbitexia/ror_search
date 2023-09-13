class ViewStateScraper
  def base_url
    raise 'please override base_url'
  end

  def initialize
    @last_url = base_url
    @last_response = RestClient::Request.execute(method: :get, url: @last_url, timeout: 120)

    @view_state = get_view_state(@last_response.body)
    @offset = 0
  rescue RestClient::ExceptionWithResponse => e
    raise_flag = true

    case e.http_code
    when 408
      failed_reason = "#{self.class.name} < ViewStateScraper Request Timeout #{base_url}"
    else
      failed_reason = "#{self.class.name} < ViewStateScraper Status code: #{e.http_code}, #{e.message}, #{base_url}"
    end
    http_code = e.http_code || nil
    if raise_flag
      raise "FailedReason: #{failed_reason}\n" +
            "Response headers: #{e.response&.headers}\n" +
            "Response body: #{e.response&.body}\n" +
            "FailedEmployeeID: 0\n" +
            "StatusCode: #{http_code}\n" +
            "FailedReasonEnd"
    end
  end

  def last_title
    Nokogiri::HTML(@last_response.body).css('h1').first.text
  end

  attr_reader :last_response

  def get_view_state(response_body)
    hash = {
      '__EVENTTARGET' => '',
      '__EVENTARGUMENT' => ''
    }

    html = Nokogiri::HTML(response_body)
    %w[__VIEWSTATE __VIEWSTATEGENERATOR __EVENTVALIDATION].each do |key|
      # p "##{key}"
      # puts response_body.include? key
      hash[key] = html.css("##{key}").first['value'] if response_body.include? key
    end

    # p hash
    hash
  end

  @@last_request_time = 0
  def do_viewstate_request(url, params = {}, dont_get_view_state = false, employee_id = 0)
    @request_period = 0.3 # seconds
    # rate-limiting to avoid spamming their site
    time_delta = Time.now.to_f - @@last_request_time.to_f
    if time_delta < @request_period
      time_remaining = @request_period - time_delta
      sleep time_remaining
    end

    # p @view_state.merge(params)
    # p @last_url

    begin
      @last_response = RestClient::Request.execute(method: :post,
                                                   url: @last_url,
                                                   payload: @view_state.merge(params),
                                                   cookies: @last_response&.cookies,
                                                   headers: { },
                                                   timeout: 120)
      RestClient::Request.execute(method: :post,
                                 url: @last_url,
                                 payload: @view_state.merge(params),
                                 cookies: @last_response&.cookies,
                                 headers: { content_type: 'application/x-www-form-urlencoded' },
                                 timeout: 120)

    rescue RestClient::ExceptionWithResponse => e
      # when using a view-state based ASP website, POSTS go to the "current" (last) URL and redirect you to the next one
      @last_response = RestClient::Request.execute(method: :get,
        url: url,
        cookies: e.response.cookies,
        timeout: 120)
        
      raise_flag = true

      raise e if e.response.nil?

      case e.http_code
      when 408
        failed_reason = "#{self.class.name} < ViewStateScraper Request Timeout #{url}"
      else
        failed_reason = "#{self.class.name} < ViewStateScraper Status code: #{e.http_code}, #{e.message}, #{url}"
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

    @last_url = url

    @view_state = get_view_state(@last_response.body) unless dont_get_view_state

    @@last_request_time = Time.now

    @last_response
  end

  def grab_view_state_from_asyncpost(body)
    keys = %w[__VIEWSTATE __VIEWSTATEGENERATOR __EVENTVALIDATION]
    values = keys.map do |key|
      body.match(/\|#{key}\|(.*?)\|/)[1]
    end
    Hash[keys.zip(values)]
  end
end
