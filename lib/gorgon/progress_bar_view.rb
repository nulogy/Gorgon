require 'ruby-progressbar'
require 'colorize'

MAX_LENGTH = 200
LOADING_MSG = "Loading environment and workers..."
RUNNING_MSG = "Running files:"

class ProgressBarView
  def initialize job_state
    @job_state = job_state
    @job_state.add_observer(self)
  end

  def show
    print LOADING_MSG
  end

  def update payload={}
    create_progress_bar_if_started_job_running

    return if @progress_bar.nil? || @finished

    failed_files_count = @job_state.failed_files_count

    @progress_bar.title="F: #{failed_files_count}"
    if failed_files_count > 0
      @progress_bar.format(format(bar: :red, title: :red))
    end

    @progress_bar.progress = @job_state.finished_files_count

    if @job_state.is_job_complete? || @job_state.is_job_cancelled?
      @finished = true
      print_summary
    end
  end

  def create_progress_bar_if_started_job_running
    if @progress_bar.nil? && @job_state.state == :running
      puts "\r#{RUNNING_MSG}#{' ' * (LOADING_MSG.length - RUNNING_MSG.length)}"
      @progress_bar = ProgressBar.create(:total => @job_state.total_files,
                                         :length => [terminal_size[0], MAX_LENGTH].min,
                                         :format => format(bar: :green, title: :white));
    end
  end

private
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

    #TODO: print other stats: time, total file, total failures, etc
  end

  def print_failed_tests
    @job_state.each_failed_test do |test|
      puts "\n" + ('*' * 80).magenta #light_red
      puts "File '#{test[:filename].cyan}' failed/crashed at '#{test[:hostname].blue}'\n"
      msg = build_fail_message test[:failures]
      puts "#{msg}\n"
    end
  end

  def build_fail_message failures
    msg = []
    failures.each do |failure|
      msg << failure
    end
    msg << ''
    result = msg.join("\n")
    result.gsub!(/^Error:/, "Error:".yellow)
    result.gsub!(/^Failure:/, "Failure:".red)
    result
  end
end
