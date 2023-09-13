module ClientsHelper
  STATES = %w[AK AL AR AZ CA CO CT DC DE FL GA HI IA ID IL IN KS KY LA MA MD ME MI MN MO MS MT NC ND NE NH NJ NM NV NY
              OH OK OR PA RI SC SD TN TX UT VA VT WA WI WV WY]
  def us_states
    STATES.zip(STATES) # => puts it in proper format for select fields
  end
end
