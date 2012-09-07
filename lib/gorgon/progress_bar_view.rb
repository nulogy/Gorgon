require 'ruby-progressbar'
require 'colorize'

MAX_LENGTH = 200

class ProgressBarView
  def initialize
    # TODO: move this to a model
    @completed = 0
    @failures = 0
    @total = 1000
  end

  def show
    @progress_bar = ProgressBar.create(:total => @total,
                                       :length => [terminal_size[0], MAX_LENGTH].min,
                                       :format => format(bar: :green, title: :white));

    # TODO: move this to a model. This is for prototyping only
    @total.times do
      sleep 0.1
      @completed+=1
      if @completed >= 50
        @failures+=1
      end
      self.update
    end
  end

  def update
    @progress_bar.title="F: #{@failures}"

    @progress_bar.progress = @completed

    if @failures > 0
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

ProgressBarView.new.show
