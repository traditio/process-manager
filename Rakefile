#coding=utf-8
require 'rake'
require 'rspec/core/rake_task'
$: << File.dirname(__FILE__)

desc "Запустить интерфейс администратора"

task :web_manager do
  ruby "web_manager/web_manager.rb"
end

desc "Запустить демон, который управляет процессами и воркерами"

task :master_process do
  ruby "master_process/master_process.rb"
end




RSpec::Core::RakeTask.new(:spec)

task :default => :spec