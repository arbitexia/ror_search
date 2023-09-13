data_directory = Rails.root.join('data')
FileUtils.mkdir(data_directory) unless File.exist?(data_directory)
