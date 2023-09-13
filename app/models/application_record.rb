class ApplicationRecord < ActiveRecord::Base
  extend Enumerize
  self.abstract_class = true

  class << self
    def sanitize_name(name)
      I18n.transliterate(name)
          .gsub(/[^a-z ]\s/i, ' ') # "alan, jr." => "alan jr"
          .gsub('-', ' ') # "jean-luc" => "jean luc"
          .gsub(/[^a-z ]/i, '') # "raymond re`ne`" => "raymond rene"
          .gsub(/\s+/, ' ')
          .strip.downcase
    end

    # used in cases where we have an external record that combines first and middle name.
    def do_first_and_middle_names_match?(internal_first_name_clean, internal_middle_name_clean, external_first_and_middle_name_clean)
      internal_first_and_middle_name_clean = "#{internal_first_name_clean} #{internal_middle_name_clean}".strip

      if internal_first_name_clean == external_first_and_middle_name_clean
        # special case: regardless of whether we were looking for a first initial, report a potential match if the external site specified NO middle initial
        return true
      end

      # if we have a match, we can return early
      return true if do_names_match?(internal_first_and_middle_name_clean, external_first_and_middle_name_clean)

      # if that didn't match, we should try matching by middle initial
      external_words = external_first_and_middle_name_clean.split(' ')
      if external_words.count < 2
        # if there is no external middle name, and we didn't match in the conditional at the start, no possible match
        return false
      end

      external_words_without_last = external_words[0...(external_words.count - 1)]
      last_external_word = external_words.last
      external_name_without_last_word = external_words_without_last.join(' ')

      unless do_names_match?(internal_first_name_clean, external_name_without_last_word)
        # if the 'first names' don't match, then we have no possible match
        return false
      end

      if internal_middle_name_clean.length == 1 || last_external_word.length == 1
        # match by middle initial
        internal_middle_initial_clean = internal_middle_name_clean.chars.first
        external_middle_initial_clean = last_external_word.chars.first

        internal_middle_initial_clean == external_middle_initial_clean
      else
        # match by full middle name if we have full middle names for both
        internal_middle_name_clean == last_external_word
      end
    end

    def do_names_match?(internal_name_clean, external_name_clean)
      internal_name_words = sanitize_name(internal_name_clean).split(' ')
      external_name_words = sanitize_name(external_name_clean).split(' ')

      if internal_name_words.count > external_name_words.count
        # no possible match
        return false
      end

      external_name_words[0...internal_name_words.count] == internal_name_words
    end
  end
end
