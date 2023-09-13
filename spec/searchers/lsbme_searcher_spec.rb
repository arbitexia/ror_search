require 'spec_helper'

describe LSBMESearcher do
  it 'should not flag Active registrations' do
    employee = Employee.new(first_name: 'Krystal', middle_name: 'Nicole', last_name: 'Brewer-Smith',
                            la_license_number: 'CLP.201215-SPE')

    results = LSBMESearcher.search_employee(employee)
    expect(results.count).to eq 0
  end

  it 'should flag Inactive registrations' do
    employee = Employee.new(first_name: 'Lynette', last_name: 'Adams-Smith', la_license_number: 'OTT.Z10680')

    results = LSBMESearcher.search_employee(employee)
    expect(results.count).to be > 0

    expect(results[0][:type]).to eq :expiry

    details = results[0][:details]
    expect(details.downcase).to include employee.first_name.downcase
    expect(details.downcase).to include employee.last_name.downcase
    expect(details.downcase).to include employee.la_license_number.downcase
    expect(details).to include 'License status: Inactive'
  end

  it 'should flag Deceased registrations' do
    employee = Employee.new(first_name: 'William', last_name: 'Arrowsmith', la_license_number: 'MD.00472R')

    results = LSBMESearcher.search_employee(employee)
    expect(results.count).to be > 0

    expect(results[0][:type]).to eq :expiry

    details = results[0][:details]
    expect(details.downcase).to include employee.first_name.downcase
    expect(details.downcase).to include employee.last_name.downcase
    expect(details.downcase).to include employee.la_license_number.downcase
    expect(details).to include 'License status: Deceased'
  end

  it 'should flag Missing registrations' do
    employee = Employee.new(first_name: 'Invalid', last_name: 'Search', la_license_number: '123472134')

    results = LSBMESearcher.search_employee(employee)
    expect(results.count).to be > 0

    expect(results[0][:type]).to eq :expiry

    details = results[0][:details]
    expect(details).to include 'No license match found on LA State Board of Medical Examiners website'
    expect(details.downcase).to include employee.la_license_number.downcase
  end

  it 'should search vendors' do
    vendor = Vendor.new(first_name: 'Krystal', middle_name: 'Nicole', last_name: 'Brewer-Smith',
                        la_license_number: 'CLP.201215-SPE')

    results = LSBMESearcher.search_vendor(vendor)
    expect(results.count).to eq 0
  end
end
