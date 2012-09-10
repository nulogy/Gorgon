require 'ruby-progressbar'
require 'colorize'

MAX_LENGTH = 200

class ProgressBarView
  def initialize job_state
    @job_state = job_state
    @job_state.add_observer(self)
  end

  def show
    @progress_bar = ProgressBar.create(:total => @job_state.total_files,
                                       :length => [terminal_size[0], MAX_LENGTH].min,
                                       :format => format(bar: :green, title: :white));
  end

  def update
    failed_files_count = @job_state.failed_files_count
    @progress_bar.title="F: #{failed_files_count}"

    @progress_bar.progress = @job_state.finished_files_count

    if failed_files_count > 0
      @progress_bar.format(format(bar: :red, title: :red))
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
end
