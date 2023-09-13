module PrettyDates
  def date_format
    '%b %d, %Y at %l:%M %p (%Z)'
  end

  def created_at_pretty
    created_at&.strftime(date_format)
  end

  def updated_at_pretty
    updated_at&.strftime(date_format)
  end
end
