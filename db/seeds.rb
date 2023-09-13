[Client, Employee, User, Report, Note, Role, Vendor].each { |model| model.destroy_all }

company_one = Client.create!(
  client_type: 'company',
  legal_business_name: 'Company One',
  physical_address: '1 Company Rd',
  physical_city: 'Testville',
  physical_state: 'TN',
  physical_zip: '35763',
  billing_same_as_mailing: true,
  primary_contact_name: 'Company Account',
  primary_contact_title: 'CEO',
  primary_contact_email: 'one@company.com',
  tax_id_number: '123456789',
  business_type: 'LLC',
  state_of_incorporation: 'DE'
)
primary_contact_one = company_one.new_contact_user('company123')
primary_contact_one.save!
company_one.update(primary_contact: primary_contact_one)

company_one.employees.create!(
  first_name: 'Zebediah',
  last_name: 'Stearns',
  la_license_number: 'MD.024862'
)
company_one.employees.create!(first_name: "Lynette", last_name: "Adams-Smith", la_license_number: 'OTT.Z10680')

company_one.employees.create!(first_name: "Thomas", middle_name: 'H.', last_name: "Vreeland", tx_license_number: 'M0301')
company_one.employees.create!(first_name: "Adrian", middle_name: 'Mzee', last_name: "Smith", tx_license_number: 'BP20042192')

facility_a = Client.create!(
  parent: company_one,
  client_type: 'facility',
  legal_business_name: 'Facility A',
  physical_address: '1 Facility Rd',
  physical_city: 'Testville',
  physical_state: 'TN',
  physical_zip: '35763',
  billing_same_as_mailing: true,
  primary_contact_name: 'Facility Account',
  primary_contact_title: 'CEO',
  primary_contact_email: 'a@facility.com',
  tax_id_number: '123456789',
  business_type: 'LLC',
  state_of_incorporation: 'DE'
)

primary_contact_a = facility_a.new_contact_user('facility123')
primary_contact_a.save!
facility_a.update(primary_contact: primary_contact_a)

company_two = Client.create!(
  client_type: 'company',
  legal_business_name: 'Company Two',
  physical_address: '2 Company Rd',
  physical_city: 'Testville',
  physical_state: 'TN',
  physical_zip: '35763',
  billing_same_as_mailing: true,
  primary_contact_name: 'Company Account',
  primary_contact_title: 'CEO',
  primary_contact_email: 'two@company.com',
  tax_id_number: '123456789',
  business_type: 'LLC',
  state_of_incorporation: 'DE'
)
primary_contact_two = company_two.new_contact_user('company123')
primary_contact_two.save!
company_two.update(primary_contact: primary_contact_two)

facility_2 = Client.create!(
  parent: facility_a,
  client_type: 'facility',
  legal_business_name: 'Nested Fac',
  physical_address: '1234 Test Rd',
  physical_city: 'Testville',
  physical_state: 'TN',
  physical_zip: '35763',
  billing_same_as_mailing: true,
  primary_contact_name: 'Nested Account',
  primary_contact_title: 'CEO',
  primary_contact_email: 'nested@nested.com',
  tax_id_number: '123456789',
  business_type: 'LLC',
  state_of_incorporation: 'DE'
)
facility_2.new_contact_user('nested123').save!

admin = User.create!(
  email: 'dennis@dennis.com',
  password: 'dennis123',
  password_confirmation: 'dennis123',
  name: 'Dennis Dennis'
)
luciano = User.create!(
  email: 'luciano.santobuono@gmail.com',
  password: 'admin123',
  password_confirmation: 'admin123',
  name: 'Luciano Santobuono'
)
admin.add_role(:admin)
luciano.add_role(:admin)

user = User.create!(email: 'user@user.com', password: 'user123', password_confirmation: 'user123', name: 'User User', client_id: facility_a.id)
