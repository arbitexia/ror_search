module LSBMESearcher
  extend self

  def search_employee(employee)
    return [] unless employee.la_license_type == 'medical' && employee.la_license_number.present?

    search(employee.la_license_number, employee.id)
  end

  def search_vendor(vendor)
    return [] unless vendor.la_license_type == 'medical' && vendor.la_license_number.present?

    search(vendor.la_license_number)
  end

  def search(la_license_number, employee_id = 0)
    endpoint = 'https://ws.lasbme.org/api/Individual/IndividualVerifyLicenseLAMED/'
    referer = 'https://online.lasbme.org/'
    user_agent = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.149 Safari/537.36'
    payload = { SortType: 'LicenseNumber',
                SortOrder: 'asc',
                CurrentPage: 1,
                TotalRecords: 0,
                PageSize: 10,
                maxSize: 5,
                From: 0,
                To: 0,
                Data: { LicenseNumber: la_license_number,
                        LicenseTypeId: '',
                        LicenseStatusTypeId: '',
                        LicenseSpecialityTypeId: '',
                        FirstName: '',
                        LastName: '',
                        City: '',
                        StateCd: '',
                        Zip: '',
                        CountyId: '' }}

    begin
      response = RestClient::Request.execute(method: :post,
                                            url: endpoint,
                                            payload: payload,
                                            header: { Referer: referer, 'user-agent' => user_agent },
                                            timeout: 120)
    rescue RestClient::ExceptionWithResponse => e
      raise_flag = true
  
      failed_reason = "#{self.class.name} < ViewStateScraper Status code: #{e.http_code}, #{e.message}, #{base_url}"
      http_code = e.http_code || nil
      if raise_flag
        raise "FailedReason: #{failed_reason}\n" +
              "Response headers: #{e.response&.headers}\n" +
              "Response body: #{e.response&.body}\n" +
              "FailedEmployeeID: #{employee_id}\n" +
              "StatusCode: #{http_code}\n" +
              "FailedReasonEnd"
      end
    rescue StandardError => e
      http_code = e.http_code || nil
      raise "FailedReason: #{e.message}\n" +
            "Response headers: \n" +
            "Response body: \n" +
            "FailedEmployeeID: #{employee_id}\n" +
            "StatusCode: #{http_code}\n" +
            "FailedReasonEnd"
    end
                                        
    json = JSON.parse(response.body)
    success = json['Status']

    if success
      flagged_records = json['PagerVM']['Records'].select { |record| record['LicenseStatusTypeName'] != 'Active' }

      flagged_records.map do |record|
        details = 'Flagged on LA State Board of Medical Examiners as: '
        details += "#{record['LastName']}, " if record['LastName'].present?
        details += "#{record['FirstName']} " if record['FirstName'].present?
        details += record['MiddleName'] if record['MiddleName'].present?
        details += "(#{record['LicenseTypeName']})" if record['LicenseTypeName'].present?
        details += "\n"
        details += "Matched by LA License Number #{record['LicenseNumber']}\n"

        if record['LicenseStatusTypeName'].present?
          details += "License status: #{record['LicenseStatusTypeName']}"

          details += " (Code: #{record['LicenseStatusTypeCode']})" if record['LicenseStatusTypeCode'].present?
        end

        {
          row: record,
          type: :expiry,
          la_license_number: :match,
          details: details
        }
      end
    elsif json['Message'] == 'No record found.'
      [
        {
          row: [],
          type: :expiry,
          la_license_number: :no_match,
          details: "No license match found on LA State Board of Medical Examiners website.\nLicense number searched: #{la_license_number}"
        }
      ]
    else
      # failure by error
      raise "FailedReason: #Invalid response from LSBME site: #{json}\n" +
            "Response headers: \n" +
            "Response body: \n" +
            "FailedEmployeeID: #{employee_id}\n" +
            "StatusCode: \n" +
            "FailedReasonEnd"
    end

    # {"Message"=>"",
    #  "RecordId"=>0,
    #  "Status"=>true,
    #  "StatusCode"=>"00",
    #  "ResponseReason"=>nil,
    #  "PagerVM"=>
    #   {"Records"=>
    #     [{"IndividualId"=>520,
    #       "FirstName"=>"LYNETTE",
    #       "MiddleName"=>"",
    #       "LastName"=>"ADAMS-SMITH",
    #       "LicenseNumber"=>"OTT.Z10680",
    #       "LicenseStatusTypeName"=>"Inactive",
    #       "LicenseTypeName"=>"OCCUPATIONAL THERAPIST",
    #       "StreetLine1"=>"4418 AKARD AVE",
    #       "StreetLine2"=>"",
    #       "CountyId"=>nil,
    #       "City"=>"SHREVEPORT",
    #       "StateCode"=>"LA",
    #       "Zip"=>"71105-3230",
    #       "LicensePathwayName"=>nil,
    #       "OriginalLicenseDate"=>"1990-09-28T00:00:00",
    #       "LicenseEffectiveDate"=>"1990-09-28T00:00:00",
    #       "LicenseExpirationDate"=>"1995-12-31T00:00:00",
    #       "BusinessName"=>"",
    #       "ReinstatementDate"=>nil,
    #       "Speciality"=>nil,
    #       "DisciplineFlag"=>false,
    #       "TotalRecord"=>1,
    #       "Specialities"=>[],
    #       "LicenseList"=>
    #        [{"CreatedBy"=>1,
    #          "CreatedOn"=>"2019-06-22T00:00:00",
    #          "ModifiedBy"=>0,
    #          "ModifiedOn"=>nil,
    #          "IndividualLicenseGuid"=>"00000000-0000-0000-0000-000000000000",
    #          "IsAdditionalLicEndApp"=>false,
    #          "CurrentApplicationId"=>nil,
    #          "IsArchive"=>false,
    #          "IndividualLicenseId"=>402758,
    #          "IndividualId"=>520,
    #          "ApplicationId"=>nil,
    #          "ApplicationTypeId"=>nil,
    #          "LicenseTypeId"=>27,
    #          "IsLicenseTemporary"=>false,
    #          "IsLicenseActive"=>false,
    #          "LicenseNumber"=>"OTT.Z10680",
    #          "OriginalLicenseDate"=>"1990-09-28T00:00:00",
    #          "LicenseEffectiveDate"=>"1990-09-28T00:00:00",
    #          "LicenseExpirationDate"=>"1995-12-31T00:00:00",
    #          "LicenseStatusTypeId"=>4,
    #          "IsActive"=>true,
    #          "IsDeleted"=>false,
    #          "LicenseStatusTypeCode"=>"INACTIVE",
    #          "LicenseStatusTypeName"=>"Inactive",
    #          "LicenseStatusColorCode"=>"0000ff",
    #          "LicenseTypeName"=>"OCCUPATIONAL THERAPIST",
    #          "LicenseTypeCode"=>nil,
    #          "FirstName"=>nil,
    #          "MiddleName"=>nil,
    #          "LastName"=>nil,
    #          "ApplicationNumber"=>nil,
    #          "TransactionId"=>0,
    #          "ApplicationTypeName"=>nil,
    #          "Description"=>"Renewal Period from 9/28/1990 to 12/31/1995 Inactive",
    #          "LicenseDetail"=>"Inactive 2016-05-16",
    #          "OriginalLicenseDateStr"=>"09/28/1990",
    #          "LicenseEffectiveDateStr"=>"09/28/1990",
    #          "LicenseExpirationDateStr"=>"12/31/1995",
    #          "ReinstatementDateStr"=>nil,
    #          "ActionFlag"=>nil,
    #          "ExtensionGranted"=>nil,
    #          "OverrideExtensionFee"=>nil,
    #          "ExtensionRenewed"=>nil,
    #          "ReferenceNumber"=>nil,
    #          "IDNumber"=>nil,
    #          "IsWallCertificate"=>nil,
    #          "RankEffDate"=>nil,
    #          "StatusEffDate"=>nil,
    #          "CertificateNo"=>nil,
    #          "CertificateDate"=>nil,
    #          "PreviousExpirationDate"=>nil,
    #          "PreviousLicenseTypeId"=>nil,
    #          "PreviousLicenseStatusTypeId"=>nil,
    #          "OriginalLicenseNumber"=>nil,
    #          "AllowToRenew"=>nil,
    #          "PreviousLicenseTypeName"=>nil,
    #          "PreviousLicenseStatusTypeName"=>nil,
    #          "PreviousEffectiveDate"=>nil,
    #          "Prefix"=>"",
    #          "IncrementBy"=>1,
    #          "DisciplineFlag"=>false,
    #          "DisciplineStatusId"=>nil,
    #          "LicenseCategoryId"=>nil,
    #          "Specialities"=>nil,
    #          "ReinstatementDate"=>nil,
    #          "Speciality"=>nil,
    #          "LicenseDisciplineStatusName"=>"None",
    #          "CredentialType"=>"L",
    #          "CredentialTypeName"=>"License",
    #          "LicenseClassId"=>nil,
    #          "CredentialGroup"=>nil,
    #          "Comments"=>nil,
    #          "LinkIndividualLicenseId"=>nil,
    #          "ParentIndividualLicenseId"=>nil,
    #          "PublicNoPublicCode"=>nil}],
    #       "Supervisors"=>[],
    #       "Supervisees"=>[]}],
    #    "SortType"=>"LicenseNumber",
    #    "SortOrder"=>"asc",
    #    "CurrentPage"=>1,
    #    "TotalRecords"=>1,
    #    "PageSize"=>10}}
  end
end

# def setup-capybara
#   require 'selenium-webdriver'
#   require 'nokogiri'
#   require 'capybara'
#
#   # Capybara.register_driver :chrome do |app|
#   #   Capybara::Selenium::Driver.new(app, browser: :chrome)
#   # end
#
#   Capybara.register_driver :headless_chrome do |app|
#     capabilities = Selenium::WebDriver::Remote::Capabilities.chrome(
#         chromeOptions: { args: %w(headless disable-gpu no-sandbox window-size=1024,768) }
#     )
#
#     Capybara::Selenium::Driver.new app,
#                                    browser: :chrome,
#                                    desired_capabilities: capabilities
#   end
#
#   Capybara.javascript_driver = :headless_chrome
#   Capybara.configure do |config|
#     config.default_max_wait_time = 10 # seconds
#     config.default_driver = :headless_chrome
#   end
#
#   browser = Capybara.current_session
#   driver = browser.driver.browser
#
# end
