require 'ruby-progressbar'
require 'colorize'

MAX_LENGTH = 200
LOADING_MSG = "Loading environment and workers..."
RUNNING_MSG = "Running files:"
LEGEND_MSG = "Legend:\nF - failure files count\nH - number of hosts that have run files\nW - number of workers running files"

FILENAME_COLOR = :light_cyan
HOST_COLOR = :light_blue

class ProgressBarView
  def initialize job_state
    @job_state = job_state
    @job_state.add_observer(self)
  end

  def show
    print LOADING_MSG
  end

  def update payload={}
    output_gorgon_crash_message payload if gorgon_crashed? payload

    create_progress_bar_if_started_job_running

    return if @progress_bar.nil? || @finished

    failed_files_count = @job_state.failed_files_count

    @progress_bar.title="F: #{failed_files_count} H: #{@job_state.total_running_hosts} W: #{@job_state.total_running_workers}"
    if failed_files_count > 0
      @progress_bar.format(format(bar: :red, title: :default))
    end

    @progress_bar.progress = @job_state.finished_files_count

    if @job_state.is_job_complete? || @job_state.is_job_cancelled?
      @finished = true
      print_summary
    end
  end

  def create_progress_bar_if_started_job_running
    if @progress_bar.nil? && @job_state.state == :running
      print "\r#{' ' * (LOADING_MSG.length)}\r"
      puts LEGEND_MSG
      @progress_bar = ProgressBar.create(:total => @job_state.total_files,
                                         :length => [terminal_size[0], MAX_LENGTH].min,
                                         :format => format(bar: :green, title: :white));
    end
  end

private
  def gorgon_crashed? payload
     payload[:type] == "crash" && payload[:action] != "finish"
  end

  def output_gorgon_crash_message payload
    $stderr.puts "\nA #{'crash'.red} occured at '#{payload[:hostname].colorize HOST_COLOR}':"
    $stderr.puts payload[:stdout].yellow unless payload[:stdout].to_s.strip.length == 0
    $stderr.puts payload[:stderr].yellow unless payload[:stderr].to_s.strip.length == 0
    if @progress_bar.nil?
      print LOADING_MSG         # if still loading, print msg so user won't think the whole job crashed
    end
  end

  def format colors
    # TODO: decide what bar to use
    #    bar = "%b>%i".colorize(colors[:bar])
    bar = "%w>%i".colorize(colors[:bar])
    title = "%t".colorize(colors[:title])

    "%e [#{bar}] %c/%C | #{title}"
  end

  def terminal_size
    `stty size`.split.map { |x| x.to_i }.reverse
  end

  def print_summary
    print_failed_tests
    print_running_files
    #TODO: print other stats: time, total file, total failures, etc
  end

  def print_failed_tests
    @job_state.each_failed_test do |test|
      puts "\n" + ('*' * 80).magenta #light_red
      puts("File '#{test[:filename].colorize(FILENAME_COLOR)}' failed/crashed at " \
           + "'#{test[:hostname].colorize(HOST_COLOR)}'\n")
      msg = build_fail_message test[:failures]
      puts "#{msg}\n"
    end
  end

  def build_fail_message failures
    result = []
    failures.each do |failure|
      if failure.is_a?(Hash)
        result << build_fail_message_from_hash(failure)
      else
        result << build_fail_message_from_string(failure)
      end
    end

    result.join("\n")
  end

  def print_running_files
    title = "Unfinished files".yellow
    puts "\n#{title} - The following files were still running:" if @job_state.total_running_workers > 0

    @job_state.each_running_file do |hostname, filename|
      filename_str = filename.dup.colorize(FILENAME_COLOR)
      hostname_str = hostname.dup.colorize(HOST_COLOR)
      puts "\t#{filename_str} at '#{hostname_str}'"
    end
  end

  def build_fail_message_from_string failure
    result = failure.gsub(/^Error:/, "Error:".yellow)
    result.gsub!(/^Failure:/, "Failure:".red)
    result
  end

  def build_fail_message_from_hash failure
    result = "#{'Test name'.yellow}: #{failure[:test_name]}"
    result << "\n#{'Message:'.yellow} \n#{failure[:message]}" if failure[:message]
    if failure[:location]
      result << "\n#{'In:'.yellow} \n\t"
      result << failure[:location].join("\n\t")
    end
    result
  end
end
