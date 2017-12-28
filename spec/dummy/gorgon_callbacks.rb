class MyCallbacks < Gorgon::DefaultCallbacks
  def before_originate
    puts "before job starts was called"
    nil
  end

  BUNDLE_LOG_FILE||="/tmp/gorgon-bundle-install.log "
  def after_sync
    require 'bundler'
    require 'open4'

    # raise "BOOOOOOOOOOOM"
    Bundler.with_clean_env do

      pid, stdin, stdout, stderr = Open4::popen4 "bundle install > #{BUNDLE_LOG_FILE} 2>&1 "

      ignore, status = Process.waitpid2 pid

      if status.exitstatus != 0
        raise "There was an error when running 'bundle install'\n#{stderr.read}"
      end
    end
  end

  def before_creating_workers
    #sleep 0.5
    puts "BEFORE CREATING WORKERS"

    # generate a lot of output to test if it blocks on write because pipe or stdout is full
    10000.times do
      puts "filling stdout"
      $stderr.puts "filling stderr"
    end

    require 'test/unit'
    require 'minitest/unit'

    require File.expand_path('../spec/spec_helper.rb', __FILE__)

    # to test that Listener reports to Originator crashes in WorkerManager
    # raise "BOOM"
  end

  def before_start
    puts "BEFORE START CALLBACK WAS CALLED"

    # generate a lot of output to test if it blocks on write because pipe or stdout is full
    10000.times do
      puts "filling stdout"
      $stderr.puts "filling stderr"
    end

    # to test that WorkerManager reports to Originator crashes in Workers
    # raise "BOOM"
  end

  def after_complete
    # sleep 5
    # system("touch /tmp/w#{$$}-#{UUIDTools::UUID.timestamp_create.to_s}")
    puts "AFTER COMPLETE CALLBACK"
  end

  def after_job_finishes
    puts "running after_job_finishes"
  end
end

Gorgon.callbacks = MyCallbacks.new
