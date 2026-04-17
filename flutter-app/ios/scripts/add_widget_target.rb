#!/usr/bin/env ruby
# Adds the InstaGoldWidget WidgetKit extension target to Runner.xcodeproj.
# Idempotent: skips if the target already exists.

require 'xcodeproj'

project_path = File.expand_path('../../Runner.xcodeproj', __FILE__)
project = Xcodeproj::Project.open(project_path)

widget_target_name = 'InstaGoldWidget'
widget_bundle_id = 'com.ibrahym.goldtracker.InstaGoldWidget'
team_id = 'Y6S29VSUJ7'
group_id = 'group.com.ibrahym.goldtracker'

# Skip if already added
existing = project.targets.find { |t| t.name == widget_target_name }
if existing
  puts "Widget target already exists, skipping target creation."
else
  puts "Creating widget target: #{widget_target_name}"

  # Create the app extension target
  widget_target = project.new_target(
    :app_extension,
    widget_target_name,
    :ios,
    '17.0',
    project.products_group,
    :swift
  )

  # Configure build settings for each configuration
  widget_target.build_configurations.each do |config|
    config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = widget_bundle_id
    config.build_settings['PRODUCT_NAME'] = widget_target_name
    config.build_settings['INFOPLIST_FILE'] = "#{widget_target_name}/Info.plist"
    config.build_settings['CODE_SIGN_ENTITLEMENTS'] = "#{widget_target_name}/InstaGoldWidget.entitlements"
    config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
    config.build_settings['DEVELOPMENT_TEAM'] = team_id
    config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
    config.build_settings['SWIFT_VERSION'] = '5.0'
    config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
    config.build_settings['SKIP_INSTALL'] = 'NO'
    config.build_settings['MARKETING_VERSION'] = '1.0'
    config.build_settings['CURRENT_PROJECT_VERSION'] = '1'
    config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
    config.build_settings['ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME'] = 'AccentColor'
    config.build_settings['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks']
    config.build_settings['CLANG_ANALYZER_NONNULL'] = 'YES'
    config.build_settings['ENABLE_BITCODE'] = 'NO'
  end

  # Make a group for widget files
  widget_group = project.new_group(widget_target_name, widget_target_name)

  # Add Swift source
  swift_ref = widget_group.new_reference("InstaGoldWidget.swift")
  widget_target.source_build_phase.add_file_reference(swift_ref)

  # Add Info.plist as a regular file (not built)
  info_plist_ref = widget_group.new_reference("Info.plist")

  # Add entitlements as regular file (not built)
  ent_ref = widget_group.new_reference("InstaGoldWidget.entitlements")

  # Add asset catalog
  assets_ref = widget_group.new_reference("Assets.xcassets")
  widget_target.resources_build_phase.add_file_reference(assets_ref)

  # Embed the extension into the Runner app
  runner_target = project.targets.find { |t| t.name == 'Runner' }
  raise 'Runner target not found' unless runner_target

  embed_phase = runner_target.copy_files_build_phases.find { |p| p.name == 'Embed App Extensions' }
  if embed_phase.nil?
    embed_phase = runner_target.new_copy_files_build_phase('Embed App Extensions')
    embed_phase.symbol_dst_subfolder_spec = :plug_ins
  end
  build_file = embed_phase.add_file_reference(widget_target.product_reference)
  build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

  # Make Runner depend on the widget target
  runner_target.add_dependency(widget_target)

  puts "Widget target created and embedded."
end

# Add Runner.entitlements + App Group entitlement to Runner target
runner_target = project.targets.find { |t| t.name == 'Runner' }
runner_group = project.main_group['Runner']
runner_ent_path = 'Runner/Runner.entitlements'

unless runner_group.find_file_by_path('Runner.entitlements')
  runner_group.new_reference('Runner.entitlements')
end

runner_target.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = runner_ent_path
end

project.save
puts "project.pbxproj saved."
