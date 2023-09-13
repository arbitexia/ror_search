require 'spec_helper'

describe LaAdraSearcher do
  let!(:employee_one_name_and_license) do
    Employee.new(first_name: 'Shanta', last_name: 'Barnes',
                 la_license_number: '1135', la_license_type: 'adra')
  end
  let!(:employee_only_license) do
    Employee.new(first_name: 'broken', last_name: 'name',
                 la_license_number: '1057', la_license_type: 'adra')
  end
  let!(:employee_only_name) { Employee.new(first_name: 'Marilyn', last_name: 'Hamilton') }
  let!(:employee_not_found) { Employee.new(first_name: 'Not', last_name: 'Found') }

  it 'should find case and respect format, expity' do
    results = described_class.search_employee(employee_one_name_and_license)
    expect(results.count).to be > 0
    result = results.first
    expect(result[:row]).to be_present
    expect(result[:details]).to be_present
    expect(result[:force_type]).to eq(:positive)
  end

  it 'should find employee by license' do
    results = described_class.search_employee(employee_only_license)
    expect(results.count).to be > 0
    result = results.first
    expect(result[:force_type]).to eq(:potential)
  end

  it 'should find employee by name only' do
    results = described_class.search_employee(employee_only_name)
    expect(results.count).to be > 0
    result = results.first
    expect(result[:force_type]).to eq(:potential)
  end

  it 'result format should be as expected' do
    results = described_class.search_employee(employee_not_found)
    expect(results).to be_empty
  end

  it 'should search vendors' do
    vendor = Vendor.new(first_name: 'Shanta', last_name: 'Barnes')
    results = described_class.search_vendor(vendor)
    expect(results.count).to be > 0
  end
end
