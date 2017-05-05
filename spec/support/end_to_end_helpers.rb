module Gorgon
  module EndToEndHelpers
    COLOR_REGEX = /\e\[(\d+)(;\d+)*m/
    PATH_REGEX  = /^\/.+\n/
    AFTER_RUNNING_REGEX = /running after_job_finishes/

    def extract_hunk(outputs, hunkregex, strip_backtrace: false)
      hunk = outputs.grep(hunkregex)[0]
      expect(hunk).not_to be_nil
      hunk.gsub!(COLOR_REGEX, "")
      hunk.gsub!(AFTER_RUNNING_REGEX, "")
      hunk.gsub!(PATH_REGEX, "") if strip_backtrace
      hunk
    end
  end
end
