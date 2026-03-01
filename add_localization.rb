require 'xcodeproj'

project_path = 'VoiceMemo.xcodeproj'
project = Xcodeproj::Project.open(project_path)

file_path = 'Shared/Localizable.xcstrings'
group = project.main_group.find_subpath('Shared', true)

# check if file reference already exists
file_ref = group.files.find { |f| f.path == 'Localizable.xcstrings' }
if file_ref.nil?
  file_ref = group.new_file('Localizable.xcstrings')
end

targets_to_add = ['VoiceMemo iOS', 'VoiceMemo Watch App']
project.targets.each do |target|
  if targets_to_add.include?(target.name)
    # Check if file is already in build phase
    build_phase = target.resources_build_phase
    unless build_phase.files_references.include?(file_ref)
      build_phase.add_file_reference(file_ref)
      puts "Added #{file_path} to #{target.name}"
    end
  end
end

project.save
puts 'Done.'
