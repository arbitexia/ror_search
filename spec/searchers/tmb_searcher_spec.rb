require 'spec_helper'

describe TMBSearcher do
  it 'should not flag Active license registrations' do
    employee = Employee.new(first_name: 'Thomas', middle_name: 'H.', last_name: 'Vreeland', tx_license_number: 'M0301')

    results = TMBSearcher.search_employee(employee)
    expect(results.count).to eq 0
  end

  it 'should not flag Active permits' do
    employee = Employee.new(first_name: 'Aaron', middle_name: 'Michael', last_name: 'Smith',
                            tx_license_number: 'BP20068134')

    results = TMBSearcher.search_employee(employee)
    expect(results.count).to eq 0
  end

  it 'should flag Terminated registrations' do
    employee = Employee.new(first_name: 'Adrian', middle_name: 'Mzee', last_name: 'Smith',
                            tx_license_number: 'BP20042192')

    results = TMBSearcher.search_employee(employee)
    expect(results.count).to be > 0

    expect(results[0][:type]).to eq :violation

    details = results[0][:details]
    expect(details).to include 'permit terminated'
  end

  it 'should flag disciplined registrations' do
    employee = Employee.new(first_name: 'Kenneth', middle_name: '', last_name: 'Green', tx_license_number: 'H2414')

    results = TMBSearcher.search_employee(employee)
    expect(results.count).to be > 0

    expect(results[0][:type]).to eq :violation

    details = results[0][:details]
    expect(details).to include 'cancelled by board'
  end

  it 'should not flag reinstated registrations' do
    employee = Employee.new(first_name: 'Keith', middle_name: '', last_name: 'Beck', tx_license_number: 'G0607')

    results = TMBSearcher.search_employee(employee)
    expect(results.count).to eq 0
  end

  it 'should flag Expired Fee registrations' do
    employee = Employee.new(first_name: 'Aimee', middle_name: nil, last_name: 'Smith', tx_license_number: 'NC03268')

    results = TMBSearcher.search_employee(employee)
    expect(results.count).to be > 0

    expect(results[0][:type]).to eq :expiry

    details = results[0][:details]
    expect(details).to include 'expired fee'
  end

  it 'should search vendors' do
    employee = Vendor.new(first_name: 'Thomas', middle_name: 'H.', last_name: 'Vreeland', tx_license_number: 'M0301')

    results = TMBSearcher.search_vendor(employee)
    expect(results.count).to eq 0
  end
end
