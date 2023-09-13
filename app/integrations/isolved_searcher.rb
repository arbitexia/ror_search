class IsolvedSearcher

  def initialize(obj)
    if obj.is_a?(Hash)
      credential = obj
    elsif obj.is_a?(String)
      credential = CREDENTIALS.select { |cred| cred[:ENDPOINT] == obj }.first
      raise "Invalid ISolved endpoint #{obj}" unless credential.present?
    else
      raise "Invalid initialization of IsolvedSearcher with #{obj}"
    end

    @ENDPOINT = credential[:ENDPOINT]
    @CLIENT_ID = credential[:CLIENT_ID]
    @CLIENT_SECRET = credential[:CLIENT_SECRET]
  end

  def basic_authorization_header
    raw_auth_string = "#{@CLIENT_ID}:#{@CLIENT_SECRET}"
    encoded_auth_string = Base64.encode64(raw_auth_string).gsub("\n", '')

    "Basic #{encoded_auth_string}"
  end

  attr_accessor :token, :token_expiry

  def recreate_client_token
    url = "#{@ENDPOINT}/api/token"
    payload = { grant_type: 'client_credentials' }
    headers = { Authorization: basic_authorization_header }
    response = RestClient::Request.execute(method: :post,
                                          url: url,
                                          payload: payload,
                                          headers: headers,
                                          timeout: 120)
    json = JSON.parse(response.body)
    token = json['access_token']
    expires_in = json['expires_in']
    expires_date = DateTime.now + expires_in.to_i.seconds

    self.token = token
    self.token_expiry = expires_date

    token
  end

  def client_token
    # puts "token: #{token}"
    # puts "token expiry: #{token_expiry.to_i}"
    # puts "now: #{DateTime.now.to_i}"
    return token if !token.nil? && token_expiry.to_i > DateTime.now.to_i

    puts 'recreating client token'
    recreate_client_token
  end

  def bearer_authorization_header
    "Bearer #{client_token}"
  end

  def find_all_employees
    records = []
    client_ids = self.search_clients['results'].map { |c| c['id'] }
    client_ids.each do |client_id|
      legal_ids = self.search_legal_companies(client_id).map { |legal| legal['id'] }
      legal_ids.each do |legal_id|
        employees = find_employees(client_id, legal_id, nil)
        # p employees
        records.concat(employees)
      end
    end
    records
  end

  def find_all_locations
    client_ids = self.search_clients['results'].map { |c| c['id'] }
    client_ids.each do |client_id|
      legal_ids = self.search_legal_companies(client_id).map { |legal| legal['id'] }
      legal_ids.each do |legal_id|
        # p search_locations(client_id, legal_id)
      end
    end
  end

  def search_clients(page = 0)
    query = "page=#{page.to_i}"
    url = "#{@ENDPOINT}/api/clients?#{query}"

    Rails.cache.fetch(url, expires_in: 5.minutes) do
      puts 'requesting clients'
      headers = { Authorization: bearer_authorization_header }
      response = RestClient::Request.execute(method: :get,
                                            url: url,
                                            headers: headers,
                                            timeout: 120)
      JSON.parse(response.body)
    end
  end

  def search_legal_companies(client_id)
    url = "#{@ENDPOINT}/api/clients/#{client_id.to_i}/legals"

    Rails.cache.fetch(url, expires_in: 5.minutes) do
      puts "requesting legals for client #{client_id}"
      headers = { Authorization: bearer_authorization_header }
      response = RestClient::Request.execute(method: :get,
                                            url: url,
                                            headers: headers,
                                            timeout: 120)
      JSON.parse(response.body)
    end
  end

  def get_location(client_id, legal_company_id, id)
    url = "#{@ENDPOINT}/api/clients/#{client_id}/legals/#{legal_company_id}/workLocations/#{id}"
    puts url

    Rails.cache.fetch(url, expires_in: 5.minutes) do
      headers = { Authorization: bearer_authorization_header }
      response = RestClient::Request.execute(method: :get,
                                            url: url,
                                            headers: headers,
                                            timeout: 120)
      JSON.parse(response.body)
    end
  end

  def search_locations(client_id, legal_company_id)
    url = "#{@ENDPOINT}/api/clients/#{client_id}/legals/#{legal_company_id}/workLocations"

    Rails.cache.fetch(url, expires_in: 5.minutes) do
      puts "requesting locations for legal #{legal_company_id}"
      headers = { Authorization: bearer_authorization_header }
      response = RestClient::Request.execute(method: :get,
                                            url: url,
                                            headers: headers,
                                            timeout: 120)
      JSON.parse(response.body)
    end
  end

  def find_employee_by_id(client_id, legal_id, id)
    url = "#{@ENDPOINT}/api/clients/#{client_id}/legals/#{legal_id}/employeesWithSSN/#{id}"

    Rails.cache.fetch(url, expires_in: 5.minutes) do
      puts "requesting employee #{id}"
      headers = { Authorization: bearer_authorization_header }
      response = RestClient::Request.execute(method: :get,
                                            url: url,
                                            headers: headers,
                                            timeout: 120)
      JSON.parse(response.body)
    end
  end

  def find_employees(client_id, legal_company_id, work_location_id)
    url = if legal_company_id.present?
            "#{@ENDPOINT}/api/clients/#{client_id}/legals/#{legal_company_id}/employeesWithSSN"
          else
            "#{@ENDPOINT}/api/clients/#{client_id}/employeesWithSSN"
          end

    work_location_code = nil
    if work_location_id.present?
      location = get_location(client_id, legal_company_id, work_location_id)
      work_location_code = location['workLocationCode']

      if work_location_code.present?
        puts "searching for work location code #{work_location_code}"
      else
        puts "work location #{work_location_id} had no location code"
      end
    end

    base_query = 'pageSize=50'
    records = []
    has_more = true

    url = "#{url}?#{base_query}"

    while has_more
      # TODO: make caching only 5min when out of debug
      page = Rails.cache.fetch(url, expires_in: 5.hours) do
        puts "requesting a page #{url} of employees for #{client_id}/#{legal_company_id}/#{work_location_id}"
        headers = { Authorization: bearer_authorization_header }
        JSON.parse(RestClient::Request.execute(method: :get, url: url, headers: headers, timeout: 600).body)
      end

      filtered_results = page['results']
      # p filtered_results

      if work_location_code.present?
        filtered_results = filtered_results.select { |result| result['workLocation'] == work_location_code }
      end

      puts "appending #{filtered_results.count} results from #{page['results'].count} total"

      records.concat(filtered_results)

      if page['nextPageUrl'].present?
        puts page['nextPageUrl']
        url = page['nextPageUrl']
      else
        has_more = false
      end
    end

    records
  end

  def sync_employees(client)
    if client.is_company?
      client_id = client.isolved_client_id
      legal_id = nil
      work_location_id = nil
    else
      client_id = client.parent.isolved_client_id
      legal_id = client.isolved_legal_company_id
      work_location_id = client.isolved_location_id
    end

    client.update(external_sync_progress: 0, external_sync_error: nil)

    employees = find_employees(client_id, legal_id, work_location_id)

    puts "employees count: #{employees.count}"

    i = 0
    employees.each do |isolved_employee|
      i += 1
      client.update(external_sync_progress: i.to_f / employees.count.to_f)

      matching_client_employee = client.employees.select { |e| e.isolved_id.to_s == isolved_employee['id'].to_s }.first

      if isolved_employee['employmentStatus'] == 'Terminated' || isolved_employee['employmentStatus'] == 'Deceased' || isolved_employee['employmentStatus'] == 'Retired'
        matching_client_employee.destroy if matching_client_employee.present?

        puts isolved_employee['employmentStatus']
        next
      else
        puts 'active'
      end

      dob = (Date.parse(isolved_employee['birthDate']) if isolved_employee['birthDate'].present?)

      first_name_words = isolved_employee['nameAddress']['firstName'].strip.split(' ')
      middle_name = isolved_employee['nameAddress']['middleName']

      if first_name_words.last == middle_name && first_name_words.count > 1
        first_name_words = first_name_words[0...(first_name_words.count - 1)]
      end

      first_name = first_name_words.join(' ')

      attributes = {
        ssn: isolved_employee['ssn'],
        dob: dob,
        isolved_id: isolved_employee['id'].to_s,
        first_name: first_name,
        middle_name: middle_name,
        last_name: isolved_employee['nameAddress']['lastName']
      }
      if matching_client_employee.present?
        matching_client_employee.update(attributes)
        verb = 'updated'
      else
        matching_client_employee = client.employees.create!(attributes)
        verb = 'imported'
      end

      puts "#{verb} employee record (iSolved ##{matching_client_employee.isolved_id} / CSC ##{matching_client_employee.id}: #{matching_client_employee.full_name})"
    end

    puts "#{employees.count} employees processed from iSolved"

    client.update(last_external_sync_at: DateTime.now, external_sync_progress: nil, external_sync_error: nil)
  rescue StandardError => e
    client.update(external_sync_progress: nil, external_sync_error: e.to_s)
    raise e
  end

  CREDENTIALS =
      [
        # default endpoint
        {
          'ENDPOINT': 'https://myisolved.com/rest',
          'CLIENT_ID': 'b1eec7c84f3543f5915cd133781589aa',
          'CLIENT_SECRET': 'wswhARaA2n7pGAEA2QPQ9IR/tU7o4aMvwU7rPKIdj1SoXJjjQb8CjxF6eG1ktpOHwdPuQhfaCc1UjFSx0tMDRA==',
        },

        # magellan endpoint: 2023-08-30
        {
          'ENDPOINT': 'https://magellan.myisolved.com/rest',
          'CLIENT_SECRET': 'E90Lw+RfDinAC6RwDcWrTDUFqAxxqbrVZRalFH9/dRFMN5IMpSMDVHqDKjPuTPcroRnDRApX5PhkpBEVYtkS4g==',
          'CLIENT_ID': '7c2e928c4871444fbf69f0fd0518e806',
        }
      ]

  class << self
    def ENDPOINT_OPTIONS
      [
        ['', nil],
        ['Original', 'https://myisolved.com/rest'],
        ['Magellan', 'https://magellan.myisolved.com/rest'],
      ]
    end
  end
end
